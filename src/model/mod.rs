use serde::Deserialize;

#[derive(Deserialize)]
pub struct BinaryLogisticRegression {
    pub coef: Vec<f64>,
    pub intercept: f64,
    pub n_features: u64,
}

impl BinaryLogisticRegression {
    pub(crate) fn from_cbor(bytes: &[u8]) -> Result<Self, String> {
        let model: Self = serde_cbor::from_slice(bytes)
            .map_err(|e| format!("Failed to deserialize model: {e}"))?;

        if model.coef.len() != model.n_features as usize {
            return Err(format!(
                "Invalid model: coef length {} does not match n_features {}",
                model.coef.len(),
                model.n_features
            ));
        }

        Ok(model)
    }

    #[inline(always)]
    fn sigmoid(x: f64) -> f64 {
        // Numerically stable implementation. See
        // https://blog.dailydoseofds.com/p/a-highly-overlooked-point-in-the
        if x < 0.0 {
            let exp_x = (x).exp();
            exp_x / (1.0 + exp_x)
        } else {
            1.0 / (1.0 + (-x).exp())
        }
    }

    pub(crate) fn predict(&self, features: &[f32]) -> Result<f64, String> {
        if features.len() != self.n_features as usize {
            return Err(format!(
                "Expected {} features, got {}",
                self.n_features,
                features.len()
            ));
        }
        let mut dot_product = self.intercept;
        for (w, x) in self.coef.iter().zip(features.iter()) {
            dot_product += w * (*x as f64);
        }
        Ok(Self::sigmoid(dot_product))
    }
}
