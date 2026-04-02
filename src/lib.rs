use std::slice;
mod fakeprint;
use fakeprint::compute_fakeprint;
mod model;
use model::BinaryLogisticRegression;
use std::sync::LazyLock;

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

static MODEL_BYTES: &[u8] = include_bytes!("../model.cbor");
/// We use a LazyLock to ensure that the model is only deserialized on
/// the first inference call, which avoids unnecessary work for repeated calls.
static MODEL: LazyLock<BinaryLogisticRegression> = LazyLock::new(|| {
    BinaryLogisticRegression::from_cbor(MODEL_BYTES).expect("Failed to load model")
});

/// this is where we need to connect our backend
/// tt should take mono Float32 PCM samples and the input sample rate, then return our score from 0 to 1
fn infer_score(samples: &[f32], sample_rate: u32) -> f32 {
    let features = compute_fakeprint(samples, sample_rate, None, None, None).to_vec();
    MODEL.predict(&features).unwrap_or(0.0) as f32
}
