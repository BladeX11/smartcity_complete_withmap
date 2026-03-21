USE smartcity_db;

ALTER TABLE complaints
    ADD COLUMN IF NOT EXISTS ai_suggested_category VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS ai_confidence_score DECIMAL(5,4) NULL,
    ADD COLUMN IF NOT EXISTS sentiment_score DECIMAL(4,2) NULL,
    ADD COLUMN IF NOT EXISTS urgency_level ENUM('low','medium','high','critical') NULL,
    ADD COLUMN IF NOT EXISTS auto_priority_boosted TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS predicted_resolution_hours DECIMAL(8,2) NULL,
    ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500) NULL,
    ADD COLUMN IF NOT EXISTS ai_detected_issue VARCHAR(120) NULL,
    ADD COLUMN IF NOT EXISTS photo_gps_lat DECIMAL(10,7) NULL,
    ADD COLUMN IF NOT EXISTS photo_gps_lng DECIMAL(10,7) NULL,
    ADD COLUMN IF NOT EXISTS gps_verified TINYINT(1) NULL;

CREATE TABLE IF NOT EXISTS crime_predictions (
    prediction_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    location_id INT UNSIGNED NOT NULL,
    predicted_date DATE NOT NULL,
    risk_score DECIMAL(6,2) NOT NULL,
    risk_level ENUM('low','medium','high','critical') NOT NULL,
    contributing_factors JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (prediction_id),
    KEY idx_crime_pred_date (predicted_date),
    KEY idx_crime_pred_location (location_id),
    CONSTRAINT fk_crime_pred_location FOREIGN KEY (location_id)
      REFERENCES locations(location_id)
      ON DELETE CASCADE ON UPDATE CASCADE
);
