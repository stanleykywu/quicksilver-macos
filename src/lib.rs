use std::slice;

#[unsafe(no_mangle)]
pub extern "C" fn qs_run_inference(
    samples_ptr: *const f32,
    samples_len: usize,
    sample_rate: u32,
) -> f32 {
    if samples_ptr.is_null() || samples_len == 0 || sample_rate == 0 {
        return 0.0;
    }

    let samples = unsafe { slice::from_raw_parts(samples_ptr, samples_len) };
    infer_score(samples, sample_rate)
}

/// this is where we need to connect our backend
/// tt should take mono Float32 PCM samples and the input sample rate, then return our score from 0 to 1
fn infer_score(samples: &[f32], sample_rate: u32) -> f32 {
    1.0
}