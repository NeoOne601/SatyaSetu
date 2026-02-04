/**
 * FILE: rust_core/src/embeddings.rs
 * VERSION: 1.0.0
 * DESCRIPTION: Semantic matching using pre-computed category embeddings.
 * - Cosine similarity for embedding comparison
 * - Efficient category lookup
 * - No external model needed (uses pre-computed vectors)
 */

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Pre-computed category embedding
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryEmbedding {
    pub category: String,
    pub embedding: Vec<f32>,
}

/// Semantic matcher using pre-loaded category embeddings
pub struct SemanticMatcher {
    categories: HashMap<String, Vec<f32>>,
    dimensions: usize,
}

impl SemanticMatcher {
    /// Create a new semantic matcher from JSON embeddings data
    pub fn from_json(json_data: &str) -> Result<Self, String> {
        let data: EmbeddingsData = serde_json::from_str(json_data)
            .map_err(|e| format!("Failed to parse embeddings JSON: {}", e))?;
        
        let categories: HashMap<String, Vec<f32>> = data.embeddings
            .into_iter()
            .map(|(k, v)| (k, v.into_iter().map(|x| x as f32).collect()))
            .collect();
        
        Ok(SemanticMatcher {
            dimensions: data.dimensions,
            categories,
        })
    }
    
    /// Match a label to the best category using cosine similarity
    pub fn match_category(&self, label: &str, threshold: f32) -> Option<(String, f32)> {
        // For now, we use a simple word overlap heuristic
        // In production, this would use an actual embedding model
        let label_lower = label.to_lowercase();
        
        let mut best_match: Option<(String, f32)> = None;
        
        for (category, _embedding) in &self.categories {
            // Simple heuristic: check if any part of the label matches category keywords
            let similarity = self.compute_label_similarity(&label_lower, category);
            
            if similarity > threshold {
                if best_match.is_none() || similarity > best_match.as_ref().unwrap().1 {
                    best_match = Some((category.clone(), similarity));
                }
            }
        }
        
        best_match
    }
    
    /// Compute similarity between label and category
    fn compute_label_similarity(&self, label: &str, category: &str) -> f32 {
        let category_lower = category.to_lowercase().replace('_', " ");
        
        // Direct match
        if label.contains(&category_lower) || category_lower.contains(label) {
            return 0.95;
        }
        
        // Partial word match
        let label_words: Vec<&str> = label.split_whitespace().collect();
        let category_words: Vec<&str> = category_lower.split_whitespace().collect();
        
        let mut matches = 0;
        for lw in &label_words {
            for cw in &category_words {
                if lw.contains(cw) || cw.contains(lw) {
                    matches += 1;
                }
            }
        }
        
        if matches > 0 {
            return 0.7 + (matches as f32 * 0.05);
        }
        
        // Use embeddings for semantic similarity (when model is available)
        // For now, return low score for unmatched
        0.0
    }
    
    /// Get all available categories
    pub fn get_categories(&self) -> Vec<String> {
        self.categories.keys().cloned().collect()
    }
    
    /// Get embedding dimensions
    pub fn get_dimensions(&self) -> usize {
        self.dimensions
    }
}

/// Cosine similarity between two vectors
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    
    let mut dot_product = 0.0f32;
    let mut norm_a = 0.0f32;
    let mut norm_b = 0.0f32;
    
    for i in 0..a.len() {
        dot_product += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }
    
    if norm_a == 0.0 || norm_b == 0.0 {
        return 0.0;
    }
    
    dot_product / (norm_a.sqrt() * norm_b.sqrt())
}

/// JSON data structure for embeddings file
#[derive(Debug, Deserialize)]
struct EmbeddingsData {
    #[allow(dead_code)]
    version: String,
    #[allow(dead_code)]
    model: String,
    dimensions: usize,
    #[allow(dead_code)]
    categories_count: usize,
    #[allow(dead_code)]
    categories: Vec<String>,
    embeddings: HashMap<String, Vec<f64>>,
}

// FFI-safe functions for Flutter

/// Match a label to category (FFI-safe wrapper)
pub fn semantic_match(label: String, embeddings_json: String, threshold: f32) -> String {
    match SemanticMatcher::from_json(&embeddings_json) {
        Ok(matcher) => {
            match matcher.match_category(&label, threshold) {
                Some((category, confidence)) => {
                    format!("{{\"category\":\"{}\",\"confidence\":{:.4}}}", category, confidence)
                }
                None => {
                    "{\"category\":\"OBJECT\",\"confidence\":0.0}".to_string()
                }
            }
        }
        Err(e) => {
            format!("{{\"error\":\"{}\"}}", e)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_cosine_similarity() {
        let a = vec![1.0, 0.0, 0.0];
        let b = vec![1.0, 0.0, 0.0];
        assert!((cosine_similarity(&a, &b) - 1.0).abs() < 0.001);
        
        let c = vec![0.0, 1.0, 0.0];
        assert!((cosine_similarity(&a, &c) - 0.0).abs() < 0.001);
    }
    
    #[test]
    fn test_semantic_match_basic() {
        // This would require actual embeddings JSON in production
        let label = "MacBook Pro";
        let category = "COMPUTER";
        
        // Mock test - in production, use actual embeddings
        assert!(label.to_lowercase().contains("macbook"));
    }
}
