use rubato::{
    Resampler, SincFixedIn, SincInterpolationParameters, SincInterpolationType, WindowFunction,
    calculate_cutoff,
};
use scirs2_core::ndarray::{Array1, Array2, Array3, s};

mod stft;
use stft::{N_FFT, get_stft};
mod curve;
use curve::{DEFAULT_F_RANGE, curve_profile};

const NUM_CHANNELS: usize = 2;
const DEFAULT_SAMPLE_RATE: u32 = 44100; // hz
const DURATION: u32 = 30; // seconds
const NORMALIZE_MAX_DB: f32 = 5.0; // dB

/// Open an audio slice for processing, given the raw PCM float 32 data.
/// Returns a 2d array of shape [time, channels] for further processing.
pub fn open_audio_slice(pcm_audio: &[f32]) -> Array2<f32> {
    let n_samples = pcm_audio.len() / NUM_CHANNELS;
    // Convert to a 2d ndarray for processing
    Array2::from_shape_vec((n_samples, NUM_CHANNELS), pcm_audio.to_vec())
        .expect("Failed to convert PCM audio to 2D array") // returns shape [time, channels]
}
/// Resample an audio slice with shape [time, channels] to the target sample rate, if needed.
pub fn resample_audio(audio_slice: &Array2<f32>, input_rate: u32, output_rate: u32) -> Array2<f32> {
    if audio_slice.shape()[1] != NUM_CHANNELS {
        panic!(
            "Expected audio slice to have {} channels, but got {}",
            NUM_CHANNELS,
            audio_slice.shape()[1]
        );
    }

    if input_rate == output_rate {
        return audio_slice.clone();
    }

    let n_samples = audio_slice.shape()[0];
    let mut channels = Vec::with_capacity(NUM_CHANNELS);
    for ch in 0..NUM_CHANNELS {
        channels.push(audio_slice.column(ch).to_vec());
    }

    let chunk_size = n_samples.clamp(1, 2048);
    let sinc_len = 128;
    let window = WindowFunction::Blackman2;
    let params = SincInterpolationParameters {
        sinc_len,
        f_cutoff: calculate_cutoff(sinc_len, window),
        interpolation: SincInterpolationType::Quadratic,
        oversampling_factor: 256,
        window,
    };
    let mut resampler = SincFixedIn::<f32>::new(
        output_rate as f64 / input_rate as f64,
        1.1,
        params,
        chunk_size,
        NUM_CHANNELS,
    )
    .expect("Failed to initialize rubato resampler");
    let resampler_delay = resampler.output_delay();
    let mut outbuffer = vec![vec![0.0f32; resampler.output_frames_max()]; NUM_CHANNELS];
    let mut resampled_channels = vec![Vec::new(); NUM_CHANNELS];
    let mut input_slices: Vec<&[f32]> = channels.iter().map(|channel| channel.as_slice()).collect();

    while input_slices[0].len() >= resampler.input_frames_next() {
        let (nbr_in, nbr_out) = resampler
            .process_into_buffer(&input_slices, &mut outbuffer, None)
            .expect("Failed to resample audio");
        for (resampled_channel, out_channel) in resampled_channels.iter_mut().zip(outbuffer.iter())
        {
            resampled_channel.extend_from_slice(&out_channel[..nbr_out]);
        }
        for input_channel in &mut input_slices {
            *input_channel = &input_channel[nbr_in..];
        }
    }

    if !input_slices[0].is_empty() {
        let (_nbr_in, nbr_out) = resampler
            .process_partial_into_buffer(Some(&input_slices), &mut outbuffer, None)
            .expect("Failed to resample final audio chunk");
        for (resampled_channel, out_channel) in resampled_channels.iter_mut().zip(outbuffer.iter())
        {
            resampled_channel.extend_from_slice(&out_channel[..nbr_out]);
        }
    }

    let expected_output_frames =
        ((n_samples as u64 * output_rate as u64) + (input_rate as u64 / 2)) / input_rate as u64;
    let n_samples = expected_output_frames as usize;
    while resampled_channels[0].len() < resampler_delay + n_samples {
        let (_nbr_in, nbr_out) = resampler
            .process_partial_into_buffer::<Vec<f32>, Vec<f32>>(None, &mut outbuffer, None)
            .expect("Failed to flush resampler delay");
        if nbr_out == 0 {
            break;
        }
        for (resampled_channel, out_channel) in resampled_channels.iter_mut().zip(outbuffer.iter())
        {
            resampled_channel.extend_from_slice(&out_channel[..nbr_out]);
        }
    }
    // convert back to 2d array
    Array2::from_shape_vec(
        (NUM_CHANNELS, n_samples),
        resampled_channels
            .into_iter()
            .flat_map(|channel| channel.into_iter().skip(resampler_delay).take(n_samples))
            .collect(),
    )
    .expect("Failed to convert resampled audio to 2D array")
    .reversed_axes() // return shape [time, channels]
}

/// Compute the spectrogram of the given PCM audio data,
/// resampling if necessary, and only using the first `DURATION` seconds of audio for computation.
/// The output is a 3d array of shape [channels, frequency_bins, time_frames] in decibels.
/// If output_sample_rate is None, it defaults to 44.1 kHz.
/// If max_duration is None, it defaults to 30 seconds.
pub fn spectrogram(
    pcm_audio: &[f32],
    input_sample_rate: u32,
    output_sample_rate: Option<u32>,
    max_duration: Option<u32>,
) -> Array3<f32> {
    let output_sample_rate = output_sample_rate.unwrap_or(DEFAULT_SAMPLE_RATE);
    let max_duration = max_duration.unwrap_or(DURATION);

    let audio_slice = if output_sample_rate != input_sample_rate {
        let audio_slice = open_audio_slice(pcm_audio);
        resample_audio(&audio_slice, input_sample_rate, output_sample_rate)
    } else {
        open_audio_slice(pcm_audio)
    };

    // get only the first x seconds of audio for spectrogram computation
    let n_samples = (output_sample_rate * max_duration) as usize;
    // if the audio is shorter than max_duration, we will just get the spectrogram of the whole audio
    let slice_end = audio_slice.shape()[0].min(n_samples);
    let audio_slice = audio_slice.slice(s![..slice_end, ..]).to_owned();

    get_stft(&audio_slice)
}

/// Apply max normalization to the input array, with an optional maximum dB floor.
/// If max_db is None, then it defaults to 5 dB.
pub fn max_normalize(x: &Array1<f32>, max_db: Option<f32>) -> Array1<f32> {
    let max_db = max_db.unwrap_or(NORMALIZE_MAX_DB);
    let x = x.clamp(0.0, max_db);
    let max_val = x.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
    x / (1e-6 + max_val)
}

/// Given the spectrogram, compute the fakeprint by averaging across time and channels,
/// then applying a curve profile and max normalization.
/// If f_range is not provided, it defaults to (5000, 16000) Hz.
/// If sample_rate is not provided, it defaults to 44.1 kHz.
pub fn fakeprint(
    stft: &Array3<f32>,
    f_range: Option<(f32, f32)>,
    sample_rate: Option<u32>,
) -> Array1<f32> {
    let sample_rate = sample_rate.unwrap_or(DEFAULT_SAMPLE_RATE);
    let f_range = f_range.unwrap_or(DEFAULT_F_RANGE);
    let (chs, n_bins, n_frames) = stft.dim();
    let mut fp = Array1::<f32>::zeros(n_bins);
    for bin in 0..n_bins {
        let mut sum = 0.0;
        for frame in 0..n_frames {
            for ch in 0..chs {
                sum += stft[[ch, bin, frame]];
            }
        }
        fp[bin] = sum / (chs * n_frames) as f32;
    }

    let x_real = Array1::linspace(0.0, (sample_rate as f32) / 2.0, fp.len());
    let (_, fp_curve) = curve_profile(&x_real, &fp, Some(f_range), None);
    max_normalize(&fp_curve, None)
}

/// Runs the fakeprint computation end to end,
/// taking in raw PCM audio data and returning the fakeprint feature vector.
/// The input PCM audio should be in the range [-1.0, 1.0] and can be of any sample rate,
/// but it will be resampled to 44.1 kHz (or whatever the value of output_sample_rate is) for processing.
/// f_range can be used to specify the frequency range for the fakeprint, and it defaults to (5000, 16000) Hz.
/// duration can be used to specify the maximum duration of audio to use for computation, and it defaults to 30 seconds.
pub fn compute_fakeprint(
    pcm_audio: &[f32],
    input_sample_rate: u32,
    output_sample_rate: Option<u32>,
    f_range: Option<(f32, f32)>,
    duration: Option<u32>,
) -> Array1<f32> {
    if pcm_audio.is_empty() {
        panic!("pcm_audio is empty");
    }
    if pcm_audio.len() / NUM_CHANNELS < N_FFT {
        panic!(
            "pcm_audio is too short: expected at least {} samples for {} channels, but got {} samples",
            N_FFT,
            NUM_CHANNELS,
            pcm_audio.len() / NUM_CHANNELS
        );
    }
    let spectro = spectrogram(pcm_audio, input_sample_rate, output_sample_rate, duration);
    fakeprint(&spectro, f_range, output_sample_rate)
}
