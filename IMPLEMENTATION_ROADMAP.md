# Smart City Complaint System - Complete Implementation Roadmap
**Advanced AI, Analytics, and UX Enhancement Plan**

---

## TABLE OF CONTENTS
1. [PHASE 1: AI & Predictive Analytics](#phase-1-ai--predictive-analytics)
2. [PHASE 2: UI/UX Transformation](#phase-2-uiux-transformation)
3. [PHASE 3: Advanced Features & Optimization](#phase-3-advanced-features--optimization)

---

# PHASE 1: AI & Predictive Analytics

## Prompt 1: AI-Powered Complaint Categorization

### Overview
Auto-suggest complaint categories using Hugging Face's zero-shot classification model. User types description → AI returns top 3 category suggestions with confidence scores.

### Implementation Plan

#### 1. Database Schema Changes
**New columns in `complaints` table:**
```sql
ALTER TABLE complaints ADD COLUMN (
    ai_suggested_category VARCHAR(100),
    ai_suggested_cat_id SMALLINT UNSIGNED,
    ai_confidence_score DECIMAL(3,2),
    ai_suggestions_json JSON,  -- store all 3 suggestions
    user_accepted_ai_suggestion TINYINT(1) DEFAULT 0
);

ALTER TABLE complaints ADD CONSTRAINT fk_ai_suggested_cat 
  FOREIGN KEY (ai_suggested_cat_id) REFERENCES categories(cat_id);
```

#### 2. Backend Routes & Logic

**Route:** `POST /api/complaints/suggest-category`
```
Request:
{
  "description": "There's a big hole in the middle of the road causing accidents"
}

Response:
{
  "success": true,
  "suggestions": [
    {
      "category_id": 1,
      "category_name": "Pothole / Road Damage",
      "confidence": 0.92,
      "icon": "fa-road"
    },
    {
      "category_id": 9,
      "category_name": "Illegal Construction",
      "confidence": 0.67,
      "icon": "fa-building"
    },
    {
      "category_id": 17,
      "category_name": "Public Property Damage",
      "confidence": 0.54,
      "icon": "fa-hammer"
    }
  ]
}
```

**Integration Points in Flask:**
1. Install: `pip install transformers torch`
2. Create `ai_categorizer.py` module with:
   - Load pre-trained model at startup: `zero-shot-classification`
   - Candidate labels: ["Pothole", "Garbage", "Water Supply", "Sewage", ...] (from DB)
   - Cache category list in memory for speed
3. Route handler:
   - Extract description from request
   - Call AI model (async to avoid blocking)
   - Return top 3 suggestions with confidence scores

**Optimization:**
- Model loading: Load once at Flask startup, cache in memory
- Async processing: Use threading or async/await for long AI calls
- Rate limiting: Max 100 categorization requests/hour per user
- Caching: Cache identical descriptions (MD5 hash) for 24 hours

#### 3. Frontend Implementation

**Location:** `submit_complaint.html`

**Trigger:** Show suggestions after user types ≥30 characters

**UI Elements:**
- Real-time debounced input (300ms delay)
- Floating suggestion card below description textarea
- Show 3 cards with:
  - Category name + icon
  - Confidence bar (0-100%)
  - "Use this" button
  - "Continue choosing manually" link

**HTML Structure:**
```html
<textarea id="description" placeholder="Describe the issue..."></textarea>
<div id="ai-suggestions" class="hidden">
  <div class="ai-label">✨ AI Suggestions</div>
  <div class="suggestion-card" data-cat-id="1">
    <span class="confidence-badge">92%</span>
    <p class="cat-name">Pothole / Road Damage</p>
    <button class="btn-use-suggestion">Use This</button>
  </div>
  <!-- more cards -->
</div>
```

**JavaScript Logic:**
```javascript
// Debounce API calls
const categoryInput = debounce(async (text) => {
  if (text.length < 30) return;
  
  const response = await fetch('/api/complaints/suggest-category', {
    method: 'POST',
    body: JSON.stringify({ description: text })
  });
  
  const data = await response.json();
  displaySuggestions(data.suggestions);
}, 300);

// Auto-fill category when "Use This" clicked
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('btn-use-suggestion')) {
    const catId = e.target.parentElement.dataset.catId;
    setCategory(catId);
    // Mark that user accepted AI suggestion
  }
});
```

**Visual Indicator:**
- Small badge: "AI Suggested ✨ 92% confidence"
- Appears next to selected category in form

#### 4. Database Trigger
After complaint inserted, log AI confidence:
```sql
CREATE TRIGGER trg_log_ai_categorization
AFTER INSERT ON complaints
FOR EACH ROW
BEGIN
    IF NEW.ai_suggested_cat_id IS NOT NULL THEN
        INSERT INTO analytics_logs 
        VALUES (..., 'ai_categorized', 'complaint', NEW.complaint_id, 
                CONCAT('AI suggested: ', NEW.ai_suggested_category, 
                       ' (', NEW.ai_confidence_score * 100, '%)'), 
                NULL);
    END IF;
END$$
```

---

## Prompt 2: Sentiment Analysis & Urgency Detection

### Overview
Analyze complaint text for emotional intensity and urgency keywords. Auto-boost priority if high urgency detected.

### Implementation Plan

#### 1. Database Schema Changes
```sql
ALTER TABLE complaints ADD COLUMN (
    sentiment_score DECIMAL(3,2),  -- 0.0 to 10.0 anger level
    urgency_level ENUM('low','medium','high','critical'),
    urgency_keywords_found JSON,  -- ["URGENT", "emergency", "children"]
    emotional_intensity DECIMAL(3,2),  -- polarity score (TextBlob/VADER)
    auto_priority_boosted TINYINT(1) DEFAULT 0
);

-- Track priority boost reasons
ALTER TABLE analytics_logs MODIFY COLUMN meta_json JSON;
```

#### 2. Backend Route

**Route:** `POST /api/complaints/analyze-sentiment`
```
Request:
{
  "description": "URGENT: Raw sewage flooding street, children getting sick!!!",
  "title": "Emergency - Sewage Overflow"
}

Response:
{
  "success": true,
  "sentiment": {
    "anger_level": 8.5,  -- 0-10
    "emotional_intensity": 0.85,  -- polarity: -1 to 1 (mapped to 0-10)
    "urgency_level": "critical",
    "keywords_found": ["URGENT", "emergency", "children", "sick"],
    "priority_recommendation": 1,  -- Critical
    "confidence": 0.92
  }
}
```

#### 3. Sentiment Analysis Implementation

**Library Choice:** VADER (part of NLTK) - optimized for social media + urgency

**Install:** `pip install nltk textblob`

**Create `sentiment_analyzer.py`:**
```python
from nltk.sentiment import SentimentIntensityAnalyzer
import re

URGENCY_KEYWORDS = {
    'critical': ['EMERGENCY', 'URGENT', 'IMMEDIATE', 'DANGEROUS', '911'],
    'high': ['dangerous', 'urgent', 'emergency', 'critical', 'severe'],
    'medium': ['broken', 'leaking', 'flooding', 'serious'],
    'low': ['small', 'minor', 'slow', 'issue']
}

EMOTIONAL_INDICATORS = {
    'anger': ['!!!', '???', 'damn', 'bloody', 'furious'],
    'concern': ['please', 'urgent', 'children', 'family'],
    'frustration': ['again', 'still', 'another', 'repeated']
}

class SentimentAnalyzer:
    def __init__(self):
        self.sia = SentimentIntensityAnalyzer()
    
    def analyze(self, title, description):
        text = f"{title}. {description}".upper()
        
        # VADER polarity score (-1 to 1)
        scores = self.sia.polarity_scores(text)
        compound = scores['compound']  # -1 (negative) to 1 (positive)
        
        # Map compound to 0-10 anger scale
        # Negative sentiment = anger/urgency
        sentiment_score = max(0, -compound * 10)  # Higher negative = higher anger
        
        # Find urgency keywords
        urgency_found = []
        for level, keywords in URGENCY_KEYWORDS.items():
            for kw in keywords:
                if kw in text:
                    urgency_found.append(kw)
        
        # Determine urgency level
        if urgency_found:
            urgency_level = 'critical' if 'EMERGENCY' in urgency_found or 'URGENT' in urgency_found else 'high'
        elif sentiment_score > 7:
            urgency_level = 'high'
        elif sentiment_score > 4:
            urgency_level = 'medium'
        else:
            urgency_level = 'low'
        
        # Count emotional indicators
        emotion_score = 0
        for indicator, words in EMOTIONAL_INDICATORS.items():
            emotion_score += sum(1 for w in words if w in text)
        emotional_intensity = min(1.0, emotion_score / 3.0)
        
        return {
            'sentiment_score': min(10, sentiment_score),
            'urgency_level': urgency_level,
            'urgency_keywords': urgency_found,
            'emotional_intensity': emotional_intensity,
            'polarity_compound': compound
        }
```

**Flask Route Handler:**
```python
@app.route('/api/complaints/analyze-sentiment', methods=['POST'])
@login_required
def analyze_sentiment():
    data = request.get_json()
    title = data.get('title', '')
    description = data.get('description', '')
    
    analyzer = SentimentAnalyzer()
    result = analyzer.analyze(title, description)
    
    # Map urgency_level to priority_id
    priority_map = {
        'critical': 1,
        'high': 2,
        'medium': 3,
        'low': 4
    }
    recommended_priority = priority_map.get(result['urgency_level'], 3)
    
    return success({
        'sentiment': result,
        'recommended_priority': recommended_priority
    })
```

#### 4. Auto-Priority Boost Integration

**Modified `sp_auto_assign_priority` procedure:**
```sql
CREATE PROCEDURE sp_auto_assign_priority(
    IN p_complaint_id INT,
    IN p_cat_id SMALLINT,
    IN p_location_id INT,
    IN p_sentiment_score DECIMAL(3,2),
    IN p_urgency_level VARCHAR(20)
)
BEGIN
    DECLARE base_priority TINYINT;
    DECLARE freq_30days INT;
    DECLARE sentiment_priority TINYINT;
    DECLARE final_priority TINYINT;
    DECLARE boosted TINYINT DEFAULT 0;
    
    -- Base priority from category
    SELECT default_priority_id INTO base_priority
    FROM categories WHERE cat_id = p_cat_id;
    
    -- Frequency boost (existing logic)
    SELECT COUNT(*) INTO freq_30days
    FROM complaints
    WHERE cat_id = p_cat_id AND location_id = p_location_id
      AND submitted_at >= NOW() - INTERVAL 30 DAY;
    
    -- Sentiment-based priority
    SET sentiment_priority = CASE p_urgency_level
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END;
    
    -- Choose highest urgency between base and sentiment
    SET final_priority = LEAST(base_priority, sentiment_priority);
    
    -- Check if boost was applied
    IF sentiment_priority < base_priority THEN
        SET boosted = 1;
    END IF;
    
    UPDATE complaints 
    SET priority_id = final_priority,
        auto_priority_boosted = boosted
    WHERE complaint_id = p_complaint_id;
    
    -- Log
    INSERT INTO analytics_logs (log_type, entity_type, entity_id, message, meta_json)
    VALUES ('priority_assigned', 'complaint', p_complaint_id,
            CONCAT('Priority: ', final_priority, ' (boosted by sentiment)'),
            JSON_OBJECT('base', base_priority, 'sentiment', sentiment_priority, 
                       'frequency', freq_30days, 'boosted', boosted));
END$$
```

#### 5. Frontend: Urgency Indicator

**Location:** `submit_complaint.html`

**Visual:**
- Color-coded urgency meter while typing
- Green → Yellow → Orange → Red
- Updates in real-time as user types

**HTML:**
```html
<div id="urgency-meter">
  <div class="meter-label">Urgency Level</div>
  <div class="meter-bar">
    <div id="urgency-fill" class="meter-fill"></div>
  </div>
  <div id="urgency-text">Low</div>
</div>
```

**JavaScript:**
```javascript
const descriptionInput = document.getElementById('description');

descriptionInput.addEventListener('input', debounce(async (e) => {
    const text = e.target.value;
    if (text.length < 10) return;
    
    const response = await fetch('/api/complaints/analyze-sentiment', {
        method: 'POST',
        body: JSON.stringify({
            title: document.getElementById('title').value,
            description: text
        })
    });
    
    const { sentiment } = await response.json();
    
    const fillEl = document.getElementById('urgency-fill');
    const textEl = document.getElementById('urgency-text');
    const colors = {
        low: '#10b981',
        medium: '#f59e0b',
        high: '#f97316',
        critical: '#dc2626'
    };
    
    fillEl.style.width = sentiment.sentiment_score * 10 + '%';
    fillEl.style.backgroundColor = colors[sentiment.urgency_level];
    textEl.textContent = sentiment.urgency_level.toUpperCase();
}, 500));
```

---

## Prompt 3: Predictive Resolution Time

### Overview
ML model predicts complaint resolution time based on 500 historical complaints.

### Implementation Plan

#### 1. Database Schema
```sql
ALTER TABLE complaints ADD COLUMN (
    predicted_resolution_hours DECIMAL(5,2),
    predicted_resolution_range VARCHAR(50),  -- "18-24 hours"
    prediction_confidence DECIMAL(3,2),
    prediction_made_at TIMESTAMP
);

-- Training data table
CREATE TABLE resolution_predictions_log (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    complaint_id INT UNSIGNED,
    actual_hours DECIMAL(5,2),
    predicted_hours DECIMAL(5,2),
    error_percent DECIMAL(4,1),
    model_version VARCHAR(20),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id)
);
```

#### 2. ML Model: `train_resolution_predictor.py`

**Features:**
- Category type
- Location (ward)
- Priority level
- Day of week
- Month/season
- Current department workload
- Historical average for category + location combo
- User's previous complaint history

**Implementation:**

```python
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib
import mysql.connector
from datetime import datetime

class ResolutionPredictor:
    def __init__(self, mysql_config):
        self.config = mysql_config
        self.model = None
        self.le_dict = {}  # LabelEncoders for categorical features
        self.feature_names = [
            'category_id', 'priority_id', 'day_of_week', 'month', 
            'ward_id', 'dept_id', 'historical_category_avg',
            'historical_location_avg', 'dept_current_workload'
        ]
    
    def load_training_data(self):
        """Fetch resolved complaints from database"""
        conn = mysql.connector.connect(**self.config)
        query = '''
        SELECT 
            c.complaint_id,
            c.cat_id,
            c.priority_id,
            c.location_id,
            c.dept_id,
            DAYOFWEEK(c.submitted_at) as day_of_week,
            MONTH(c.submitted_at) as month,
            TIMESTAMPDIFF(HOUR, c.submitted_at, c.resolved_at) as resolution_hours
        FROM complaints c
        WHERE c.status IN ('resolved', 'closed')
            AND c.resolved_at IS NOT NULL
            AND TIMESTAMPDIFF(HOUR, c.submitted_at, c.resolved_at) > 0
        ORDER BY c.resolved_at DESC
        LIMIT 500
        '''
        df = pd.read_sql(query, conn)
        conn.close()
        return df
    
    def engineer_features(self, df):
        """Create feature columns"""
        # Historical averages
        df['historical_category_avg'] = df.groupby('cat_id')['resolution_hours'].transform('mean')
        df['historical_location_avg'] = df.groupby('location_id')['resolution_hours'].transform('mean')
        
        # Department workload (complaints assigned but not resolved in last 7 days)
        # This would be fetched dynamically; for now estimate as average
        df['dept_current_workload'] = 5
        
        return df
    
    def train(self):
        """Train the model"""
        print("Loading training data...")
        df = self.load_training_data()
        
        if len(df) < 100:
            print(f"Warning: Only {len(df)} training samples. Need at least 100.")
            return False
        
        print(f"Training data: {len(df)} samples")
        
        # Engineer features
        df = self.engineer_features(df)
        
        # Prepare X, y
        X = df[self.feature_names].copy()
        y = df['resolution_hours'].copy()
        
        # Handle missing values
        X.fillna(X.mean(), inplace=True)
        
        # Encode categorical features (if any are categories)
        for col in ['priority_id']:
            if col in X.columns:
                self.le_dict[col] = LabelEncoder()
                X[col] = self.le_dict[col].fit_transform(X[col])
        
        # Train/test split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Try both models and keep the better one
        print("Training Random Forest...")
        rf_model = RandomForestRegressor(
            n_estimators=100,
            max_depth=15,
            min_samples_split=5,
            random_state=42,
            n_jobs=-1
        )
        rf_model.fit(X_train, y_train)
        rf_pred = rf_model.predict(X_test)
        rf_mae = mean_absolute_error(y_test, rf_pred)
        rf_r2 = r2_score(y_test, rf_pred)
        
        print(f"Random Forest - MAE: {rf_mae:.2f}h, R²: {rf_r2:.3f}")
        
        print("Training Gradient Boosting...")
        gb_model = GradientBoostingRegressor(
            n_estimators=100,
            learning_rate=0.1,
            max_depth=5,
            random_state=42
        )
        gb_model.fit(X_train, y_train)
        gb_pred = gb_model.predict(X_test)
        gb_mae = mean_absolute_error(y_test, gb_pred)
        gb_r2 = r2_score(y_test, gb_pred)
        
        print(f"Gradient Boosting - MAE: {gb_mae:.2f}h, R²: {gb_r2:.3f}")
        
        # Choose better model
        self.model = rf_model if rf_mae < gb_mae else gb_model
        self.model_type = 'RandomForest' if rf_mae < gb_mae else 'GradientBoosting'
        self.model_accuracy = rf_mae if rf_mae < gb_mae else gb_mae
        
        # Save model
        joblib.dump(self.model, 'models/resolution_predictor.pkl')
        joblib.dump(self.le_dict, 'models/label_encoders.pkl')
        
        print(f"✓ Model trained and saved ({self.model_type})")
        print(f"  Expected error: ±{self.model_accuracy:.1f} hours")
        
        return True
    
    def predict(self, complaint_data):
        """Predict resolution time for new complaint"""
        if not self.model:
            self.model = joblib.load('models/resolution_predictor.pkl')
            self.le_dict = joblib.load('models/label_encoders.pkl')
        
        features = np.array([[
            complaint_data['cat_id'],
            complaint_data['priority_id'],
            complaint_data['day_of_week'],
            complaint_data['month'],
            complaint_data['location_id'],
            complaint_data['dept_id'],
            complaint_data['historical_category_avg'],
            complaint_data['historical_location_avg'],
            complaint_data['dept_workload']
        ]])
        
        predicted_hours = float(self.model.predict(features)[0])
        
        # Convert to range (±margin)
        margin = self.model_accuracy * 1.2
        lower = max(0.5, predicted_hours - margin)
        upper = predicted_hours + margin
        
        return {
            'predicted_hours': round(predicted_hours, 1),
            'range_low': round(lower, 1),
            'range_high': round(upper, 1),
            'confidence': 0.85  # Mock; real = R² score
        }

# Training script
if __name__ == '__main__':
    config = {
        'host': 'localhost',
        'user': 'root',
        'password': 'admin',
        'database': 'smartcity_db'
    }
    
    predictor = ResolutionPredictor(config)
    predictor.train()
    
    # Test prediction
    test_data = {
        'cat_id': 1,
        'priority_id': 2,
        'day_of_week': 3,
        'month': 3,
        'location_id': 5,
        'dept_id': 1,
        'historical_category_avg': 36.5,
        'historical_location_avg': 42.0,
        'dept_workload': 8
    }
    
    pred = predictor.predict(test_data)
    print(f"\nPrediction: {pred['predicted_hours']}h ({pred['range_low']}-{pred['range_high']}h)")
```

#### 3. Flask Route

**Route:** `GET /api/complaints/{id}/predicted-time`

```python
@app.route('/api/complaints/<int:complaint_id>/predicted-time', methods=['GET'])
def get_predicted_resolution_time(complaint_id):
    complaint = query_db(
        '''SELECT c.cat_id, c.priority_id, c.location_id, c.dept_id, c.submitted_at
           FROM complaints WHERE complaint_id = %s''',
        (complaint_id,), fetchone=True
    )
    
    if not complaint:
        return error('Complaint not found', 404)
    
    # Calculate features
    from datetime import datetime
    submitted_date = datetime.fromisoformat(complaint['submitted_at'])
    day_of_week = submitted_date.isoweekday()
    month = submitted_date.month
    
    # Calculate historical averages
    avg_category = query_db(
        '''SELECT AVG(TIMESTAMPDIFF(HOUR, submitted_at, resolved_at)) as avg
           FROM complaints WHERE cat_id = %s AND resolved_at IS NOT NULL''',
        (complaint['cat_id'],), fetchone=True
    )
    
    avg_location = query_db(
        '''SELECT AVG(TIMESTAMPDIFF(HOUR, submitted_at, resolved_at)) as avg
           FROM complaints WHERE location_id = %s AND resolved_at IS NOT NULL''',
        (complaint['location_id'],), fetchone=True
    )
    
    dept_workload = query_db(
        '''SELECT COUNT(*) as count FROM complaints 
           WHERE dept_id = %s AND status NOT IN ('resolved', 'closed')
           AND submitted_at >= NOW() - INTERVAL 7 DAY''',
        (complaint['dept_id'],), fetchone=True
    )
    
    feature_dict = {
        'cat_id': complaint['cat_id'],
        'priority_id': complaint['priority_id'],
        'day_of_week': day_of_week,
        'month': month,
        'location_id': complaint['location_id'],
        'dept_id': complaint['dept_id'],
        'historical_category_avg': avg_category['avg'] or 24,
        'historical_location_avg': avg_location['avg'] or 30,
        'dept_workload': dept_workload['count']
    }
    
    predictor = ResolutionPredictor(DB_CONFIG)
    prediction = predictor.predict(feature_dict)
    
    # Save to DB
    query_db(
        '''UPDATE complaints 
           SET predicted_resolution_hours = %s,
               predicted_resolution_range = %s,
               prediction_confidence = %s,
               prediction_made_at = NOW()
           WHERE complaint_id = %s''',
        (prediction['predicted_hours'], 
         f"{prediction['range_low']}-{prediction['range_high']} hours",
         prediction['confidence'],
         complaint_id),
        commit=True
    )
    
    return success({
        'predicted_hours': prediction['predicted_hours'],
        'range_low': prediction['range_low'],
        'range_high': prediction['range_high'],
        'range_text': f"{prediction['range_low']}-{prediction['range_high']} hours",
        'confidence': prediction['confidence']
    })
```

#### 4. Frontend: Display Prediction

**Location:** `submit_complaint.html` (after form submission)

**Show:** "Estimated resolution: 18-24 hours based on similar cases"

**Admin Dashboard:** Tracking accuracy
- Chart: Predicted vs Actual (scatter plot)
- Metrics: MAE, RMSE across time
- Filter: By category, location, department

---

## Prompt 4: Crime Prediction Heatmap

### Overview
Predict high-risk crime zones for next 7 days using time-series and location density analysis.

### Implementation Plan

#### 1. Database Schema
```sql
CREATE TABLE crime_predictions (
    prediction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    location_id INT UNSIGNED NOT NULL,
    predicted_date DATE NOT NULL,
    time_of_day VARCHAR(20),  -- 'morning', 'afternoon', 'evening', 'night'
    risk_score DECIMAL(3,2),  -- 0-100 normalized to 0-1
    risk_level ENUM('low','medium','high','critical'),
    crime_type_likely VARCHAR(100),  -- Most probable crime types
    contributing_factors JSON,  -- street_lights_out: true, traffic_density: high
    confidence DECIMAL(3,2),
    model_version VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    UNIQUE KEY unique_prediction (location_id, predicted_date, time_of_day),
    KEY idx_date (predicted_date),
    KEY idx_risk (risk_score)
);

ALTER TABLE crime_incidents ADD COLUMN (
    time_of_day ENUM('morning','afternoon','evening','night')
);
```

#### 2. ML Model: Crime Prediction

**Features for prediction:**
- Historical crime density (past 90 days)
- Day-of-week patterns (crimes spike on weekends)
- Time-of-day patterns (night crimes > day crimes)
- Location clustering (nearby areas)
- Environmental factors (broken street lights → more robberies)
- Correlated complaints (water supply issues → social unrest)
- Holiday/event calendar

**Algorithm Choice:** Prophet (Facebook) for time-series + Random Forest for spatial

```python
import pandas as pd
import numpy as np
from prophet import Prophet
from sklearn.preprocessing import MinMaxScaler
import mysql.connector
from datetime import datetime, timedelta
import json

class CrimePredictionModel:
    def __init__(self, mysql_config):
        self.config = mysql_config
        self.scaler = MinMaxScaler()
    
    def load_crime_data(self, days_back=90):
        """Load historical crime data"""
        conn = mysql.connector.connect(**self.config)
        query = f'''
        SELECT 
            ci.incident_id,
            ci.incident_date,
            ci.incident_time,
            CASE 
                WHEN HOUR(ci.incident_time) BETWEEN 6 AND 11 THEN 'morning'
                WHEN HOUR(ci.incident_time) BETWEEN 12 AND 17 THEN 'afternoon'
                WHEN HOUR(ci.incident_time) BETWEEN 18 AND 20 THEN 'evening'
                ELSE 'night'
            END as time_of_day,
            ci.location_id,
            l.ward_number,
            ct.type_name,
            ct.severity
        FROM crime_incidents ci
        JOIN locations l ON ci.location_id = l.location_id
        JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
        WHERE ci.incident_date >= CURDATE() - INTERVAL {days_back} DAY
        ORDER BY ci.incident_date, ci.incident_time
        '''
        df = pd.read_sql(query, conn)
        conn.close()
        return df
    
    def load_complaint_data(self, days_back=90):
        """Load complaint data to find correlations"""
        conn = mysql.connector.connect(**self.config)
        query = f'''
        SELECT 
            c.submitted_at as date,
            c.location_id,
            cat.cat_name,
            c.priority_id
        FROM complaints c
        JOIN categories cat ON c.cat_id = cat.cat_id
        WHERE c.submitted_at >= CURDATE() - INTERVAL {days_back} DAY
        '''
        df = pd.read_sql(query, conn)
        conn.close()
        return df
    
    def predict_per_location(self, location_id, history_df):
        """Use Prophet for time-series prediction per location"""
        location_crimes = history_df[history_df['location_id'] == location_id].copy()
        
        if len(location_crimes) < 10:
            return None  # Not enough data
        
        # Prepare for Prophet
        daily_counts = location_crimes.groupby('incident_date').size().reset_index(name='y')
        daily_counts.columns = ['ds', 'y']
        daily_counts['ds'] = pd.to_datetime(daily_counts['ds'])
        
        # Train Prophet
        model = Prophet(
            yearly_seasonality=True,
            weekly_seasonality=True,
            daily_seasonality=False,
            interval_width=0.95
        )
        model.fit(daily_counts)
        
        # Forecast next 7 days
        future = model.make_future_dataframe(periods=7)
        forecast = model.predict(future)
        
        return forecast
    
    def calculate_risk_factors(self, location_id, complaints_df, crimes_df):
        """Calculate risk based on environmental factors"""
        # Broken street lights in this location
        light_complaints = len(complaints_df[
            (complaints_df['location_id'] == location_id) &
            (complaints_df['cat_name'].str.contains('Street Light', case=False, na=False)) &
            (complaints_df['date'] >= datetime.now() - timedelta(days=30))
        ])
        
        light_risk = min(1.0, light_complaints / 5)
        
        # Sewage issues + crime correlation
        sewage_complaints = len(complaints_df[
            (complaints_df['location_id'] == location_id) &
            (complaints_df['cat_name'].str.contains('Sewage|Water', case=False, na=False))
        ])
        sewage_risk = 0.3 if sewage_complaints > 2 else 0
        
        # Recent crime history
        recent_crimes = len(crimes_df[
            (crimes_df['location_id'] == location_id) &
            (crimes_df['incident_date'] >= datetime.now().date() - timedelta(days=30))
        ])
        crime_risk = min(1.0, recent_crimes / 10)
        
        # Time-of-day patterns
        night_crimes = len(crimes_df[
            (crimes_df['location_id'] == location_id) &
            (crimes_df['time_of_day'] == 'night')
        ])
        total_crimes = len(crimes_df[crimes_df['location_id'] == location_id])
        night_risk = (night_crimes / max(1, total_crimes)) * 0.7
        
        return {
            'street_light_factor': light_risk,
            'sewage_factor': sewage_risk,
            'recent_crime_factor': crime_risk,
            'night_time_risk': night_risk,
            'combined_risk': light_risk * 0.3 + sewage_risk * 0.2 + crime_risk * 0.4 + night_risk * 0.1
        }
    
    def predict_all_locations(self):
        """Generate predictions for all locations"""
        crimes_df = self.load_crime_data()
        complaints_df = self.load_complaint_data()
        
        predictions = []
        locations = crimes_df['location_id'].unique()
        
        for loc_id in locations:
            forecast = self.predict_per_location(loc_id, crimes_df)
            if forecast is None:
                continue
            
            risk_factors = self.calculate_risk_factors(loc_id, complaints_df, crimes_df)
            
            # Get forecast for next 7 days
            for idx in range(-7, 0):
                row = forecast.iloc[idx]
                pred_date = pd.to_timestamp(row['ds']).date()
                
                # Normalize forecast to 0-100 risk score
                base_risk = min(1.0, max(0, row['yhat']) / 5.0)  # Normalized
                risk_score = (base_risk * 0.6 + risk_factors['combined_risk'] * 0.4)
                
                risk_level = 'critical' if risk_score > 0.75 else \
                             'high' if risk_score > 0.5 else \
                             'medium' if risk_score > 0.25 else 'low'
                
                predictions.append({
                    'location_id': loc_id,
                    'predicted_date': pred_date,
                    'risk_score': risk_score,
                    'risk_level': risk_level,
                    'factors': risk_factors
                })
        
        return predictions
    
    def save_predictions(self, predictions):
        """Save to database"""
        conn = mysql.connector.connect(**self.config)
        cursor = conn.cursor()
        
        for pred in predictions:
            cursor.execute('''
                INSERT INTO crime_predictions 
                (location_id, predicted_date, risk_score, risk_level, contributing_factors)
                VALUES (%s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    risk_score = VALUES(risk_score),
                    risk_level = VALUES(risk_level),
                    contributing_factors = VALUES(contributing_factors)
            ''', (
                pred['location_id'],
                pred['predicted_date'],
                pred['risk_score'],
                pred['risk_level'],
                json.dumps(pred['factors'])
            ))
        
        conn.commit()
        cursor.close()
        conn.close()

# Run daily at midnight
if __name__ == '__main__':
    model = CrimePredictionModel(DB_CONFIG)
    predictions = model.predict_all_locations()
    model.save_predictions(predictions)
    print(f"✓ Generated {len(predictions)} crime predictions")
```

#### 3. Flask Route

**Route:** `GET /api/predictions/crime-hotspots`

```python
@app.route('/api/predictions/crime-hotspots', methods=['GET'])
def get_crime_hotspots():
    """Get predicted crime hotspots for next 7 days"""
    days = int(request.args.get('days', 7))
    risk_level = request.args.get('risk_level')  -- optional filter
    
    where = [f'predicted_date BETWEEN CURDATE() AND CURDATE() + INTERVAL {days} DAY']
    params = []
    
    if risk_level:
        where.append('risk_level = %s')
        params.append(risk_level)
    
    rows = query_db(f'''
        SELECT 
            cp.prediction_id,
            cp.location_id,
            l.area_name,
            l.ward_number,
            l.zone,
            l.latitude,
            l.longitude,
            cp.predicted_date,
            cp.risk_score,
            cp.risk_level,
            cp.contributing_factors,
            COUNT(ci.incident_id) as recent_crimes_30d
        FROM crime_predictions cp
        JOIN locations l ON cp.location_id = l.location_id
        LEFT JOIN crime_incidents ci ON ci.location_id = cp.location_id
            AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY
        WHERE {' AND '.join(where)}
        GROUP BY cp.prediction_id, cp.location_id, cp.predicted_date
        ORDER BY cp.risk_score DESC, cp.predicted_date ASC
    ''', params)
    
    return success({
        'hotspots': rows,
        'generated_at': datetime.now().isoformat(),
        'model_version': '1.0'
    })
```

#### 4. Frontend: Heatmap Integration

**Location:** `city_map.html`

**Features:**
1. Add "Crime Prediction Heatmap" layer toggle
2. Use Leaflet HeatLayer or Mapbox heatmap
3. Gradient: Green (low) → Yellow → Orange → Red (critical)
4. Pulsing markers for critical zones
5. Tooltip: Risk score, factors, preventive measures

**HTML/JS:**
```javascript
// Fetch predictions and add heatmap layer
async function loadCrimePredictions() {
    const response = await fetch('/api/predictions/crime-hotspots?days=7');
    const data = await response.json();
    
    // Create heatmap points
    const heatPoints = data.hotspots.map(h => [
        h.latitude,
        h.longitude,
        h.risk_score  // Weight for heatmap
    ]);
    
    // Add heatmap layer
    L.heatLayer(heatPoints, {
        radius: 40,
        blur: 35,
        max: 1.0,
        minOpacity: 0.3,
        gradient: {0.0: 'green', 0.33: 'yellow', 0.66: 'orange', 1.0: 'red'}
    }).addTo(map);
    
    // Add markers for critical zones
    data.hotspots
        .filter(h => h.risk_level === 'critical')
        .forEach(h => {
            L.circleMarker([h.latitude, h.longitude], {
                radius: 12,
                color: '#dc2626',
                weight: 2,
                opacity: 1,
                fillOpacity: 0.7,
                className: 'crime-hotspot-critical'
            })
            .bindPopup(`<strong>${h.area_name}</strong><br/>Risk: ${h.risk_level}<br/>Score: ${(h.risk_score * 100).toFixed(0)}%`)
            .addTo(map);
        });
}

loadCrimePredictions();
```

**Admin Alert:**
```sql
-- Trigger to create alert when critical prediction generated
CREATE TRIGGER trg_crime_alert
AFTER INSERT ON crime_predictions
FOR EACH ROW
BEGIN
    IF NEW.risk_level = 'critical' THEN
        INSERT INTO admin_alerts (title, message, alert_type, severity, data_json)
        VALUES (
            CONCAT('Crime Risk Alert: ', (SELECT area_name FROM locations WHERE location_id = NEW.location_id)),
            CONCAT('Predicted high ', 'crime risk in ', (SELECT ward_number FROM locations WHERE location_id = NEW.location_id)),
            'crime_prediction',
            'high',
            JSON_OBJECT('prediction_id', NEW.prediction_id, 'risk_score', NEW.risk_score)
        );
    END IF;
END$$
```

---

## Prompt 5: Image Recognition for Complaints

### Overview
AI analyzes complaint photos to detect issue type and extracts metadata (GPS, timestamp).

### Implementation Plan

#### 1. Database Schema
```sql
ALTER TABLE complaints ADD COLUMN (
    photo_url VARCHAR(500),
    ai_detected_issue VARCHAR(150),
    photo_ai_confidence DECIMAL(3,2),
    photo_gps_lat DECIMAL(10,7),
    photo_gps_lng DECIMAL(10,7),
    photo_timestamp DATETIME,
    gps_verified TINYINT(1) DEFAULT 0,
    gps_mismatch_flagged TINYINT(1) DEFAULT 0
);

CREATE TABLE complaint_photos (
    photo_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    complaint_id INT UNSIGNED NOT NULL,
    photo_url VARCHAR(500) NOT NULL,
    ai_analysis JSON,  -- {detected_object, confidence, suggestions}
    gps_data JSON,  -- {latitude, longitude, accuracy, timestamp}
    upload_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id) ON DELETE CASCADE,
    KEY idx_complaint (complaint_id)
);

-- Flag suspicious photos
CREATE TABLE flagged_photos (
    flag_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    photo_id INT UNSIGNED NOT NULL,
    flag_reason VARCHAR(100),  -- gps_mismatch, low_quality, irrelevant
    severity VARCHAR(20),  -- low, medium, high
    reviewed TINYINT(1) DEFAULT 0,
    admin_notes TEXT,
    FOREIGN KEY (photo_id) REFERENCES complaint_photos(photo_id) ON DELETE CASCADE
);
```

#### 2. Image Analysis Service

**Models:** Use TensorFlow with MobileNetV3 (lightweight) + custom fine-tuning

```python
import tensorflow as tf
import numpy as np
from PIL import Image
from io import BytesIO
import base64
import piexif  # For EXIF data (GPS)
from datetime import datetime
import requests

class UrbanIssueDetector:
    def __init__(self, model_path='models/urban_detector.h5'):
        # Pre-trained model
        self.model = tf.keras.models.load_model(model_path)
        
        # Issue categories
        self.issue_classes = [
            'pothole',
            'garbage_pile',
            'broken_light',
            'flooded_area',
            'illegal_dumping',
            'damaged_building',
            'broken_footpath',
            'other'
        ]
    
    def analyze_image(self, image_base64, lat=None, lng=None):
        """
        Analyze image for urban issues
        Returns: {detected_issue, confidence, suggested_category_id, gps_data}
        """
        try:
            # Decode base64
            image_data = base64.b64decode(image_base64)
            image = Image.open(BytesIO(image_data))
            
            # Extract GPS from EXIF if available
            gps_info = self._extract_gps_from_exif(image_data)
            
            # Resize for model input
            img_array = np.array(image.resize((224, 224))) / 255.0
            img_array = np.expand_dims(img_array, axis=0)
            
            # Predict
            predictions = self.model.predict(img_array)[0]
            
            # Get top prediction
            top_idx = np.argmax(predictions)
            top_confidence = float(predictions[top_idx])
            detected_issue = self.issue_classes[top_idx]
            
            # Get all predictions for sorting
            all_predictions = [
                {
                    'issue': self.issue_classes[i],
                    'confidence': float(predictions[i])
                }
                for i in np.argsort(predictions)[::-1][:3]
            ]
            
            return {
                'detected_issue': detected_issue,
                'confidence': top_confidence,
                'all_predictions': all_predictions,
                'gps_from_exif': gps_info,
                'suggested_gps': {
                    'lat': lat or gps_info.get('latitude'),
                    'lng': lng or gps_info.get('longitude'),
                    'accuracy': gps_info.get('accuracy', 'unknown')
                }
            }
        
        except Exception as e:
            return {
                'error': str(e),
                'detected_issue': 'unknown',
                'confidence': 0
            }
    
    def _extract_gps_from_exif(self, image_data):
        """Extract GPS coordinates from EXIF metadata"""
        try:
            exif_dict = piexif.load(image_data)
            gps_ifd = exif_dict.get("GPS")
            
            if not gps_ifd:
                return {}
            
            # Parse GPS data
            def convert_to_degrees(value):
                d = float(value[0][0]) / float(value[0][1])
                m = float(value[1][0]) / float(value[1][1])
                s = float(value[2][0]) / float(value[2][1])
                return d + (m / 60) + (s / 3600)
            
            lat = convert_to_degrees(gps_ifd[piexif.GPSIFD.GPSLatitude])
            lng = convert_to_degrees(gps_ifd[piexif.GPSIFD.GPSLongitude])
            
            lat_ref = gps_ifd[piexif.GPSIFD.GPSLatitudeRef].decode()
            lng_ref = gps_ifd[piexif.GPSIFD.GPSLongitudeRef].decode()
            
            if lat_ref != 'N':
                lat = -lat
            if lng_ref != 'E':
                lng = -lng
            
            return {
                'latitude': lat,
                'longitude': lng,
                'accuracy': 'exif',
                'timestamp': datetime.now().isoformat()
            }
        except:
            return {}
    
    def verify_gps_match(self, photo_lat, photo_lng, complaint_location_id):
        """Check if photo GPS matches complaint location"""
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute(
            'SELECT latitude, longitude FROM locations WHERE location_id = %s',
            (complaint_location_id,)
        )
        location = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not location:
            return False
        
        # Calculate distance (simplified)
        from math import radians, sin, cos, sqrt, atan2
        
        def haversine(lat1, lon1, lat2, lon2):
            R = 6371  # Earth radius in km
            lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
            dlat = lat2 - lat1
            dlon = lon2 - lon1
            a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
            c = 2 * atan2(sqrt(a), sqrt(1-a))
            return R * c * 1000  # in meters
        
        distance = haversine(photo_lat, photo_lng, 
                           location['latitude'], location['longitude'])
        
        # Flag if > 500m away
        return distance <= 500, distance
```

#### 3. Flask Route

**Route:** `POST /api/complaints/analyze-image`

```python
@app.route('/api/complaints/analyze-image', methods=['POST'])
@login_required
def analyze_image():
    data = request.get_json()
    image_base64 = data.get('image')  # base64 encoded
    complaint_id = data.get('complaint_id')  # optional
    lat = data.get('latitude')  # opt GPS override
    lng = data.get('longitude')
    
    if not image_base64:
        return error('Image required', 400)
    
    detector = UrbanIssueDetector()
    analysis = detector.analyze_image(image_base64, lat, lng)
    
    if 'error' in analysis:
        return error(analysis['error'], 400)
    
    # Verify GPS if complaint_id provided
    gps_verified = False
    gps_mismatch = False
    
    if complaint_id and analysis['suggested_gps']['lat']:
        complaint = query_db(
            'SELECT location_id FROM complaints WHERE complaint_id = %s',
            (complaint_id,), fetchone=True
        )
        if complaint:
            is_match, distance = detector.verify_gps_match(
                analysis['suggested_gps']['lat'],
                analysis['suggested_gps']['lng'],
                complaint['location_id']
            )
            gps_verified = is_match
            gps_mismatch = not is_match
    
    # Save analysis
    if complaint_id:
        # Suggest category based on detected issue
        category_map = {
            'pothole': 1,
            'garbage_pile': 4,
            'broken_light': 3,
            'flooded_area': 6,
            'illegal_dumping': 5,
            'damaged_building': 9,
            'broken_footpath': 2
        }
        suggested_cat_id = category_map.get(analysis['detected_issue'], 18)
        
        query_db(
            '''UPDATE complaints 
               SET ai_detected_issue = %s,
                   photo_ai_confidence = %s,
                   photo_gps_lat = %s,
                   photo_gps_lng = %s,
                   gps_verified = %s,
                   gps_mismatch_flagged = %s
               WHERE complaint_id = %s''',
            (analysis['detected_issue'],
             analysis['confidence'],
             analysis['suggested_gps']['lat'],
             analysis['suggested_gps']['lng'],
             gps_verified,
             gps_mismatch,
             complaint_id),
            commit=True
        )
        
        # Flag if mismatch
        if gps_mismatch:
            query_db(
                '''INSERT INTO flagged_photos (photo_id, flag_reason, severity)
                   SELECT photo_id, 'gps_mismatch', 'high'
                   FROM complaint_photos
                   WHERE complaint_id = %s
                   ORDER BY upload_timestamp DESC LIMIT 1''',
                (complaint_id,),
                commit=True
            )
    
    return success({
        'detected_issue': analysis['detected_issue'],
        'confidence': analysis['confidence'],
        'all_predictions': analysis['all_predictions'],
        'gps': analysis['suggested_gps'],
        'gps_verified': gps_verified,
        'gps_mismatch': gps_mismatch,
        'suggested_category_id': category_map.get(analysis['detected_issue'])
    })
```

#### 4. Frontend: Image Upload

**Location:** `submit_complaint.html`

**Features:**
- Drag-drop area for images
- Live preview
- AI detection result badge
- GPS verification warning

**HTML:**
```html
<div class="image-upload-area">
    <div id="dropZone" class="drop-zone">
        <svg class="upload-icon"><!-- cloud upload --></svg>
        <p>Drag image here or <label><input type="file" id="imageInput" accept="image/*"></label></p>
    </div>
    <div id="imagePreview" class="hidden">
        <img id="previewImg" src="#">
        <div id="aiAnalysis" class="ai-badge hidden">
            <span class="spinner"></span> Analyzing...
        </div>
    </div>
</div>
```

**JavaScript:**
```javascript
const dropZone = document.getElementById('dropZone');
const imageInput = document.getElementById('imageInput');
const previewImg = document.getElementById('previewImg');

// Handle drag-drop
dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('active');
});

dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('active');
    handleImage(e.dataTransfer.files[0]);
});

imageInput.addEventListener('change', (e) => {
    handleImage(e.target.files[0]);
});

async function handleImage(file) {
    const reader = new FileReader();
    reader.onload = async (e) => {
        const base64 = e.target.result;
        previewImg.src = base64;
        document.getElementById('imagePreview').classList.remove('hidden');
        
        // Get GPS from device
        const position = await getDeviceLocation();
        
        // Send to backend for analysis
        const response = await fetch('/api/complaints/analyze-image', {
            method: 'POST',
            body: JSON.stringify({
                image: base64.replace(/^data:image\/\w+;base64,/, ''),
                latitude: position?.latitude,
                longitude: position?.longitude
            })
        });
        
        const result = await response.json();
        
        showAIBadge(result);
    };
    reader.readAsDataURL(file);
}

function showAIBadge(result) {
    const badge = document.getElementById('aiAnalysis');
    badge.innerHTML = `
        <strong>AI Detected:</strong> ${result.detected_issue.toUpperCase()}
        <span class="confidence">${(result.confidence * 100).toFixed(0)}%</span>
        ${result.gps_mismatch ? '<span class="warning">⚠ GPS Mismatch</span>' : ''}
    `;
    badge.classList.remove('hidden');
}
```

---

# PHASE 2: UI/UX TRANSFORMATION

## Prompt 6: Modern UI Redesign - Landing Page

### Overview
Redesign `index.html` with modern, premium aesthetics (Apple/Airbnb level).

### Design Architecture

#### 1. Layout Structure
```
Hero Section
├─ Animated gradient background (deep blue → electric blue)
├─ Floating glassmorphism cards
├─ 3D city illustration (Three.js or Spline)
└─ CTA buttons (Report Issue, View Status)

Featured Section
├─ Live statistics counter (animated count-up)
├─ Key metrics: Issues reported, Fixed, Resolution rate
└─ Real-time data from API

Social Proof Section
├─ Testimonial carousel
├─ Citizen photos, names, impact stories
└─ Auto-scroll with pause on hover

Features Grid
├─ 4-6 feature cards with icons
├─ Hover effect: card elevates, icon animates
└─ Icon glow effect on hover

CTA Section
├─ Email newsletter signup
└─ Social media links

Footer
├─ Dark, minimal
└─ Links, legal, contact
```

#### 2. Animation Timeline
| Element | Trigger | Animation | Duration |
|---------|---------|-----------|----------|
| Gradient bg | Page load | Subtle color shift | 15s loop |
| Hero cards | Load (stagger) | Fade + slide up | 0.6s (100ms stagger) |
| 3D city | Load | Slight rotate + bounce | 2s |
| Statistics | User scrolls to | Count-up animation | 2.5s |
| Feature cards | User hovers | Lift up 12px + shadow | 0.3s |
| Icons | Card hover | Rotate 360° + scale | 0.8s |
| Testimonials | Auto-scroll | Fade transitions | 0.8s (5s pause each) |
| CTA button | Hover | Expand + glow pulse | 0.4s |

#### 3. Color Palette & Typography
**Colors:**
- Primary: `#0f172a` (deep blue) to `#3b82f6` (electric blue)
- Accent: `#06b6d4` (cyan), `#10b981` (green)
- Text: `#ffffff` (light), `#0f172a` (dark)
- Backgrounds: `#f8fafc` (light), `#0f172a` (dark)

**Typography:**
- Headlines: Inter Bold, size 48-64px, line-height 1.1
- Subheadings: Inter Semibold, 28-32px
- Body: Inter Regular, 16px, 1.6 line-height
- Small text: Inter Medium, 14px

**Spacing:**
- Section padding: 80px top/bottom (mobile: 40px)
- Gap between elements: 24px
- Card padding: 32px

#### 4. Design System Components

**Glassmorphism Cards:**
```css
.card-glass {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 16px;
    padding: 32px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}
```

**Micro-interactions:**
- Buttons: Scale 1.05 on hover, glow effect
- Icons: Rotate 360°, color change
- Cards: Lift with shadow increment

#### 5. Key Page Sections

**Hero (Above fold 100vh):**
- Large headline: "Stop complaining. Start fixing."
- Subheading: "Pune's fastest way to report city issues"
- Value props: 3 short bullets (transparency, speed, impact)
- Visual: 3D Pune city model with floating complaint icons

**Statistics (Full-width):**
- 4 cards, count-up animation
- Issues Reported, Fixed this month, Avg resolution time, Citizen satisfaction
- Fetch from `/api/dashboard/overview`

**Features (3-column grid):**
- Cloud-based reporting
- Real-time tracking
- Data-driven decisions
- AI-powered suggestions
- (Icon, title, 1-line description per card)

**Testimonials (Carousel):**
- Face photo, name, role, quote, result achieved
- Loop 6-8 testimonials
- Pagination dots at bottom

**Newsletter CTA:**
- Email input + subscribe button
- Success toast message
- Privacy note: "No spam, unsubscribe anytime"

#### 6. Mobile Optimization
- Stack sections vertically
- Hero: 60vh, reduced font sizes
- Statistics: 2x2 grid instead of 4 across
- Feature cards: Single column
- Testimonials: Full-width, swipe gestures
- Hamburger menu for sticky nav

---

## Prompt 7: Premium Dashboard Redesign

### Overview
Transform `admin_dashboard.html` into analytics-rich, beautiful interface (Stripe/Linear inspiration).

### Information Architecture

#### 1. Layout: Split-Screen + Quick Actions Panel
```
┌─────────────┬──────────────────────────┬──────────────┐
│   Sidebar   │   Main Content Area      │ Quick Actions│
│ Navigation  │─────────────────────────── (Right panel)|
│  Filters    │  KPI Cards with trends   │              │
│  Date range │─────────────────────────── • Bulk actions
│  Presets    │  Charts (interactive)    │  • Templates
│             │  (Complaints, Categories)│  • Filters
│             │─────────────────────────── • Export
│             │  Data table (drill-down) │  • Settings
└─────────────┴───────────────────────────┴──────────────┘
```

#### 2. Component Hierarchy

**KPI Cards (Top row):**
```
┌─ Total Complaints (this month)   ┌─ Avg Resolution Time
│  Number: 847 (↑12% vs last)      │  18h 32m (↓8%)
│  Sparkline: 7-day trend          │  Sparkline: green ✓
│  Mini chart showing daily count  │  Target: 24h
│                                  │
┌─ Pending Issues                  ┌─ Resolution Rate
│  234 (12 critical)               │  76.5% (↑4%)
└─────────────────────────────────── Target: 85%
```

**Charts Row:**
```
┌─────────────────────────────────────────────────┐
│  Complaints by Category (pie/bar toggle)        │
│  Sewage   ▓▓▓▓▓▓▓ 28%                           │
│  Pothole  ▓▓▓▓▓   20%                           │
(interactive - click segment to filter everything)
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Priority Breakdown (stacked bar)               │
│  Critical ▓▓▓ High ▓▓▓▓ Medium ▓▓▓▓▓ Low ▓▓    │
└─────────────────────────────────────────────────┘
```

**Data Table (Drill-down):**
- Complaint ID, Category, Location, Priority, Assigned Officer, Status
- Click row → Detail panel on right side
- Sortable columns, filterable
- Inline status badge (color-coded)

#### 3. Interaction Patterns

**Date Range Picker:**
- Presets: Today, Last 7 days, Last 30 days, Custom
- Shows selected range in header
- All charts react to date change instantly

**Filter & Drill-Down:**
- Click chart segment → filters main table below
- Apply multiple filters: AND logic
- Visual: "Filters applied (3)" chip with X to clear

**Comparison Mode:**
- Toggle "Compare" button
- Side-by-side metrics: This month vs last month
- Cards show: Number, % change, trend indicator

**Real-time Updates (WebSocket):**
- New complaint comes in → KPI numbers update instantly
- Visible "Live" indicator in top-right
- Animated green flash on updated cells

**Export:**
- PDF with dashboard snapshot + current data
- Custom branding (city logo, date range)
- Charts exported as images
- Table data as CSV

#### 4. Animation Choreography

| Layer | Trigger | Animation |
|-------|---------|-----------|
| Cards load | Page load (stagger) | Fade + slide up (80ms intervals) |
| Chart elements | Chart render | Bar/segment growth (0.6s ease-out) |
| Hover on card | Mouse enter | Subtle shadow expand + scale 1.02 |
| Data cell update | Real-time update | Yellow highlight flash → fade |
| Sort/filter | Click | Smooth list reflow (0.3s) |
| Modal open | Click row | Slide from right (0.4s) |

#### 5. Data Visualization Best Practices

**Complaints Trend:**
- Line chart, 30-day rolling
- Color: Gradient blue to green (good trend)
- Show: Current, average, target
- Hover: Show exact values + SLA % for that day

**Category Distribution:**
- Donut chart (not pie - hollow center for icon)
- Top 5 categories, "Others" aggregated
- Hover: Show count + % + recent complaint in category

**Priority by Status:**
```
Critical:    3 pending | 12 assigned | 8 in-progress | 14 resolved
High:        5 pending | 28 assigned | ...
```
(Stacked horizontal bars, can expand/collapse category)

**Department Performance:**
- Heatmap: Dept × Week, cell value = avg resolution hours
- Green (fast) to red (slow)
- Sortable by avg time

#### 6. Power User Features

**Keyboard Shortcuts:**
- `?` → Show help modal with all shortcuts
- `/` → Command palette (search any action)
- `j/k` → Next/previous row
- `e` → Edit selected
- `c` → Comment
- `Shift+Enter` → Bulk action

**Smart Suggestions:**
- "Duplicate complaint detected" when hovering over details
- "This officer usually resolves this category in 12h" (contextual)
- "SLA about to breach in 3h" alert

**Customizable Dashboard:**
- Drag-drop widget reordering
- Save layout preferences (per user)
- Multiple dashboard tabs (e.g., "Today", "My Assigned", "SLA Risk")

---

## Prompt 8: Citizen Complaint Submission - Gamified UX

### Overview
Redesign `submit_complaint.html` as engaging conversational flow with gamification.

### User Journey Map
```
1. Landing
   ↓ "Hey! What's the issue?" (friendly greeting)
   
2. Issue Selection (AI guided)
   ↓ Chatbot: "Tell me what's happening..."
   
3. Category Confirmation
   ↓ "AI suggests: Pothole" (with confidence) | Confirm / Change
   
4. Location Picking
   ↓ Interactive map with satellite view | "Tap to mark location"
   
5. Photo Upload
   ↓ "Show us a photo?" (optional) | Instagram-style preview
   ↓ AI detection: "I see a pothole! 🕳️"
   
6. Details & Impact
   ↓ Smart autocomplete: "pothole on [street names]"
   ↓ Show: "847 potholes fixed with your help! 🎉"
   ↓ Leaderboard: "142 people in Ward 12 reported issues"
   
7. Estimated Resolution
   ↓ "Based on similar complaints: 2-3 days"
   
8. Submit & Celebrate
   ↓ Confetti animation 🎉
   ↓ Achievement card (shareable)
   ↓ "Impact Score" badge earned
```

### Micro-Copy Examples (Tone: Friendly, Empowering)

```
Landing:
"Hey! What's the issue? 👋"
(vs boring: "Complaint Description")

Category Selection:
"Let me guess... Pothole? (87% sure) ✨"
"If not, here are other options"

Photo Upload:
"A picture is worth 👍. Help us out?"
"Optional, but photos help us get faster!" 

Location Picker:
"Tap exactly where this is happening"
"Satellite view on the right 📡"

Progress:
"Nice! You're helping Pune get better 🙌"
"One more step..."

Success:
"You're awesome! 🎉 You've helped fix 3 issues!"
"Share your achievement" [Social buttons]
```

### Gamification Psychology

**Progress Visibility:**
- Multi-step form shown as progress bar (step 3/7)
- Checkmarks for completed steps
- Estimated time: "This takes ~2 min"

**Badges & Achievements:**
```
🏅 First Reporter    - Report your first issue
🕳️  Pothole Hunter   - Report 5 potholes
🌍 Ward Warrior       - Report 3+ issues in your ward
⚡ Quick Fix         - 5 complaints resolved in <1 day
🤝 Community Champion - 10+ reports in a month
🌟 Super Helper       - 50+ reports lifetime
```

**Leaderboard (Privacy-Respecting):**
- "Top contributors in Ward 12 this month"
- Show: User first name, # of reports, recent activity
- Opt-in (checkbox: "Show me on the leaderboard")
- Current user highlighted

**Social Proof:**
- "142 people in your area reported issues this week"
- "You + 47 neighbors fixed 12 issues last month! 🎊"
- Real-time ticker: "Someone just reported a [issue] in [location]"

**Estimated Impact:**
- "With your help, we've fixed: 847 potholes, 1,231 street lights, ..."
- Show progress to city goals (e.g., "0% potholes remaining")
- Before/after photos when issue is resolved

### Animation Moments (Delight)

```javascript
// Confetti on submit success
fireConfetti({
    particleCount: 50,
    spread: 45,
    origin: { y: 0.5 }
});

// Checkmark animation for each step
animateCheckmark(element, duration: 600);

// Achievement badge pop-in
badge.animate([
    { transform: 'scale(0)', opacity: 0 },
    { transform: 'scale(1.2)' },
    { transform: 'scale(1)' }
], { duration: 600, easing: 'cubic-bezier(0.34, 1.56, 0.64, 1)' });

// Number count-up animation
animateCountUp(startValue, endValue, duration: 1500);
```

### Accessibility Considerations

- **Keyboard Navigation:** Tab through all form elements
- **Screen Reader:** ARIA labels for "Step 3 of 7", buttons
- **Color Contrast:** Badges visible without color alone
- **Motion:** Respect `prefers-reduced-motion` (disable animations)
- **Focus Indicator:** Visible 3px outline on all interactive elements
- **Error Messages:** Clear, actionable, linked to form field

---

## Prompt 9: Interactive City Map - Next-Gen Visualization

### Overview
Transform `city_map.html` into stunning, data-rich geospatial experience.

### Feature Prioritization Matrix

| Priority | Feature | Impact | Effort | Notes |
|----------|---------|--------|--------|-------|
| P0 | Complaint markers | High | Low | Core feature |
| P0 | Category/priority filtering | High | Low | Quick wins |
| P0 | Cluster markers | High | Medium | Handle 10k+ points |
| P1 | Time slider (6 months) | High | High | Pattern discovery |
| P1 | Heat layers (complaint, crime) | High | Medium | Toggle layers |
| P2 | 3D visualization | Medium | High | Eye candy |
| P2 | Journey mode animation | Low | High | Nice-to-have |
| P3 | Street-view integration | Low | High | Extra polish |

### Map Layer Architecture

```
┌─ Base Layer
│  ├─ OSM / Mapbox (dark theme)
│  └─ Custom styling: minimal labels
│
├─ Data Layers (toggleable)
│  ├─ Complaint points
│  │  ├─ Color by category
│  │  └─ Size by priority
│  ├─ Crime incidents
│  │  └─ Skull icons, high opacity
│  ├─ Crime prediction heatmap
│  │  └─ Gradient overlay (green→red)
│  └─ Department zones
│     └─ Glow borders for active depts
│
├─ Dynamic Elements
│  ├─ Cluster circles (animated expand)
│  ├─ Trajectory lines (crew movement)
│  └─ Resolved markers (particle effect)
│
└─ Overlay UI
   ├─ Layer toggle buttons (top-right)
   ├─ Time slider (bottom)
   ├─ Filter panel (left)
   └─ Legend (bottom-left)
```

### Performance Optimization (10,000+ markers)

**Clustering:**
```javascript
// Use Leaflet.markercluster
L.markerClusterGroup({
    maxClusterRadius: 80,
    iconCreateFunction: (cluster) => {
        const count = cluster.getChildCount();
        return L.divIcon({
            html: `<span class="cluster-count">${count}</span>`,
            className: 'custom-cluster'
        });
    }
})
```

**Virtual Rendering:**
- Only render visible viewport + buffer zone
- Remove off-screen markers dynamically
- Rebuild cluster group on pan/zoom (debounced)

**Data Decimation:**
- Aggregate complaints by 100m grid cell past 30 days
- Show individual pins only when zoomed > level 15
- Query: `POST /api/map/aggregate?zoom=14&bbox=...`

**Caching:**
- Cache GeoJSON response (1 hour TTL)
- Service worker: offline fallback (stale data)
- IndexedDB: 30-day local history

### Advanced Interactions

**Right-Click Context Menu:**
```javascript
map.addEventListener('contextmenu', (e) => {
    showContextMenu(e.latlng, {
        'Report issue here': reportIssue,
        'Get directions': getDirections,
        'View history': viewHistory,
        'Copy coordinates': copyCoords
    });
});
```

**Multi-Select Polygon:**
```javascript
// Draw mode: Shift + drag to select multiple
// Bulk actions: Change priority, assign officer, close resolved
```

**Story Mode:**
```javascript
// Auto-play tour showing key insights
const keyPoints = [
    { name: 'Hadapsar', coords: [18.5018, 73.9263], 
      message: '12 pothole complaints, 9 resolved' },
    { name: 'Koregaon Park', coords: [18.5362, 73.8938],
      message: 'Avg resolution: 18 hours' }
];

async function playStoryMode() {
    for (const point of keyPoints) {
        map.flyTo(point.coords, 16, { duration: 2 });
        await showPopup(point.message);
        await sleep(5000);
    }
}
```

### Animation Design Language

**Complaint Lifecycle Journey:**
```
Submitted ▷ Assigned ▷ In-Progress ▷ Resolved
  🔵      ▷   🟡    ▷     🟠      ▷   🟢
(Animate line flowing, pulse dots)
```

**Pulsing Active Incidents:**
```css
@keyframes pulse {
    0% { opacity: 1; box-shadow: 0 0 0 0; }
    70% { opacity: 1; box-shadow: 0 0 0 20px rgba(255,0,0,0); }
    100% { opacity: 1; box-shadow: 0 0 0 30px rgba(255,0,0,0); }
}
```

**Particle Effects (Resolved):**
```javascript
// Show confetti burst when complaint marked as resolved
particleSystem.emit({
    position: markerLatLng,
    velocity: (particles) => particles.map(() => ({
        x: Math.random() * 4 - 2,
        y: Math.random() * -4
    })),
    lifetime: 1500
});
```

### Mobile Map Patterns

- **Bottom Sheet:** Slide up to see complaint details
- **Tap & Hold:** Long-press to add complaint at location
- **Compass:** Rotate map to North on double-tap
- **Swipe Filters:** Left/right to toggle layers
- **Haptic Feedback:** Buzz on marker interaction

---

## Prompt 10: Notification System - Contextual & Smart

### Overview
Intelligent notifications that users actually engage with (not generic spam).

### Notification Taxonomy

```
TRANSACTIONAL (Real-time, urgent)
├─ Status Update: "Your complaint #CMP-2024-00567 crew arriving in 30 min"
│  └─ Data: GPS location, photo, estimated arrival
├─ SLA Alert: "Your complaint is at risk of missing SLA (2h remaining)"
│  └─ Action: Escalate, Contact officer
└─ Urgent Warning: "Raw sewage flooding detected in your area!"
   └─ Action: Alert authorities, View on map

PERSONALIZED (Weekly/daily digest)
├─ Impact Report: "This week: You reported 3 issues, 2 fixed! 🎉"
│  └─ Include: Photos before/after
├─ Completion Story: "The pothole you reported on XYZ street is FIXED"
│  └─ Include: Completion photo, thanks from city
└─ Nearby Activity: "3 new complaints in your area (Ward 12)"
   └─ Action: Join discussion, upvote

PREDICTIVE (Proactive alerts)
├─ Weather Alert: "Heavy rain predicted. Expect water complaints"
│  └─ Link to: Prevention tips, help desk
├─ Seasonal Alert: "Monsoon prep: Report damage early for faster fixes"
└─ Crime Prediction: "High theft risk in Hadapsar this weekend"
   └─ Action: View map, Police contact

ENGAGEMENT (Gentle nudges)
├─ Dormant User: "You haven't checked your complaint in 3 days"
├─ Holiday: "Send a quick update from vacation?"
└─ Incentive: "Report 2 more issues to unlock 'Ward Guardian' badge"

SOCIAL (Community)
├─ Trending: "Pothole complaints up 40% this week in Ward 12"
├─ Leaderboard: "You're #5 this month! 1 more report for top 3"
└─ Discussion: "@officer_sharma replied to your complaint"
```

### Personalization Engine Logic

```javascript
class NotificationPersonalizer {
    constructor(userId, serviceObj) {
        this.userId = userId;
        this.service = service;
    }
    
    // Determine best delivery time (when user likely to check)
    async getOptimalDeliveryTime() {
        const userActivity = await this.service.getUserActivityPattern(this.userId);
        // ML model trained on past engagement
        // Returns: 14:30 (2:30 PM most likely to open)
        return userActivity.peakEngagementTime;
    }
    
    // Determine delivery channel
    async selectChannel(notificationType) {
        // urgent → push + SMS
        // summary → email (batch)
        // social → push only
        const preference = await this.service.getUserPreferences(this.userId);
        return {
            critical: ['push', 'sms'],
            high: ['push', 'email'],
            medium: ['push'],
            low: ['email_digest']
        }[notificationType.priority];
    }
    
    // Batch related notifications
    async aggregateNotifications(notifications) {
        // Instead of 5 separate alerts, send 1:
        // "Your 5 complaints: 2 fixed, 2 assigned, 1 pending"
        return this.service.groupByTheme(notifications);
    }
    
    // Personalize message based on user demographics
    async personalizeMessage(template, user) {
        if (user.language === 'marathi') {
            return translateToMarathi(template);
        }
        // Replace placeholders with actual data
        return template
            .replace('{{user}}', user.first_name)
            .replace('{{location}}', user.area_name)
            .replace('{{count}}', user.recent_report_count);
    }
}
```

### UI Design Patterns

**Notification Center:**
```
╔════════════════════════════════════╗
║ Notifications        [Mark All Read]║
╠════════════════════════════════════╣
║ 📍 UPDATES (5)                      ║
│  ├─ ✓ Complaint #567 assigned      │
│  ├─ Status: In-progress            │
│  └─ [View] [Rate] [Archive]        │
│                                     │
║ ⚠️  ALERTS (2)                      ║
│  ├─ SLA breach risk in 3h           │
│  └─ [Escalate] [Snooze]            │
│                                     │
║ 📊 REPORTS (1)                      │
│  └─ Weekly impact: 3 fixed, +2★     │
│     [View Report]                  │
╚════════════════════════════════════╝
```

**Notification Card (Inline in app):**
```
┌─────────────────────────────────────┐
│ 🎉 Your pothole was FIXED!         │
│                                     │
│ [Before Photo] → [After Photo]     │
│                                     │
│ "Repaired on Mar 18, cost: ₹15k"  │
│                                     │
│ [Thank Officer] [Share] [⋯]        │
└─────────────────────────────────────┘
```

**Push Notification (Mobile):**
```
📍 Complaint #567: Crew arriving in 25 min 🚗
[View Details] [Track Live]
```

### Delivery Optimization

**Time Optimization (ML-based):**
- Analyze past engagement: when user opens notifications
- Optimal time = 68% avg open rate
- Store in user profile: `notification_peak_time: 14:30`
- Send at that time (with ±30min variance)

**Frequency Capping:**
- Max 2 notifications/day per user (configurable)
- Queue excess → daily email digest at 8 AM
- Exceptions: Critical alerts always immediate

**Quiet Hours:**
- Default: 10 PM - 8 AM (no notifications)
- User can customize
- Except: Critical/emergency (always notify)

**Channel Preference:**
```sql
CREATE TABLE user_notification_preferences (
    user_id INT UNSIGNED,
    notification_type VARCHAR(50),
    channel ENUM('push', 'email', 'sms', 'in_app'),
    enabled TINYINT(1) DEFAULT 1,
    quiet_hours_enabled TINYINT(1),
    frequency_limit INT,  -- per day
    PRIMARY KEY (user_id, notification_type, channel)
);
```

### User Control Settings

**Granular Preferences:**
```
Notifications → Manage → 

Status Updates
  ☑ Assigned to me
  ☑ Status change
  ☑ Close to resolution
  🔧 Frequency: Per update / Digest

Alerts & Warnings
  ☑ SLA breach warnings
  ☑ Critical issues
  ☑ Weather/event alerts
  🔧 Push / Email / SMS toggle

Community & Leaderboard
  ☐ Leaderboard ranking
  ☐ Trending topics
  ☑ Direct @mentions

Delivery
  🔧 Quiet hours: 10 PM - 8 AM
  🔧 Preferred channels: [Push] [Email]
  🔧 Daily digest time: 8:00 AM
```

---

# PHASE 3: Advanced Features & Optimization

## Prompt 11: Admin Complaint Management - Power User Interface

### Overview
Redesign `admin_complaints.html` for maximum efficiency (Linear/Airtable-style).

### Information Density vs Readability Balance

**Principle:** Show all necessary info without cognitive overload

```
Row height:  40px (fits ~20 rows per fold)
Columns:     ID | Category | Location | Priority | Officer | Status | Days Open
Color coding: Priority= red/orange/yellow, Status = grayscale/green
White space: 12px between rows, 8px between columns

Density options:
├─ Compact (20 rows)
├─ Normal (14 rows)
└─ Spacious (8 rows)

Hover behavior:
├─ Show full text in tooltip (vs truncated cell)
├─ Reveal inline edit button
└─ Highlight row with subtle background
```

### Keyboard Shortcut System

```
NAVIGATION:
  j/k       Next/previous row
  g+g       Go to first row
  G         Go to last row
  /         Search/filter (cmd palette)

ACTIONS:
  e         Edit (selected row detail panel)
  c         Comment
  s         Toggle star (favorite)
  d         Delete / Archive
  m         Assign to me
  Shift+M   Assign to other (modal)

STATUS MANAGEMENT:
  1-4       Set priority (1=Critical, 4=Low)
  p         Cycle status (pending→assigned→progress→resolved)
  r         Mark resolved
  x         Mark rejected / close

BULK (with selection):
  Shift+j/k Multi-select
  Ctrl+a    Select all on page
  Ctrl+Shift+a  Select all filtered
  e         Bulk edit
  d         Bulk delete
  m         Bulk reassign

SETTINGS:
  ?         Show help
  Ctrl+,    Preferences
  Ctrl+'    Toggle sidebar
```

### State Management Approach

**Frontend Architecture:**
```javascript
class ComplaintManager {
    constructor() {
        this.complaints = [];  // Cached data
        this.selectedRows = new Set();  // Selection state
        this.filters = {};  // Applied filters
        this.sortBy = { column: 'submitted_at', direction: 'desc' };
        this.virtualScroll = null;  // Render optimization
    }
    
    // Apply filters without refetching
    filter(column, operator, value) {
        this.filters[column] = { operator, value };
        this.applyFiltersLocally();
    }
    
    // Multi-column sort
    sort(columns) {
        this.sortBy = columns;  // [{col: 'priority', dir: 'desc'}, {...}]
        this.complaints.sort((a, b) => {
            for (const { col, dir } of columns) {
                if (a[col] !== b[col]) {
                    return dir === 'asc' ? a[col] - b[col] : b[col] - a[col];
                }
            }
        });
    }
    
    // Optimistic UI update
    async updateComplaint(id, fields) {
        // 1. Optimistically update UI
        const complaint = this.complaints.find(c => c.id === id);
        const original = { ...complaint };
        Object.assign(complaint, fields);
        this.render();
        
        // 2. Send to server
        try {
            await api.patch(`/complaints/${id}`, fields);
            // Success - keep UI update
        } catch (error) {
            // Revert
            Object.assign(complaint, original);
            this.render();
            showError(error.message);
        }
    }
}
```

### Performance for 10,000+ Row Tables

**Virtual Scrolling:**
- Render only 20-30 visible rows + buffer
- As user scrolls, swap rows in/out of DOM
- Use Scroller library or native scroll events

**Lazy Loading:**
- Initial load: 500 rows (5 pages)
- Load next 500 on: scroll near bottom, sort, filter change
- Pagination with "Load more" button fallback

**Batched Updates:**
- Debounce filter changes (300ms)
- Debounce sort (200ms)
- Request only changed columns on scroll

**Indexing Strategy:**
```sql
-- Database optimization
ALTER TABLE complaints ADD INDEX idx_status_date (status, submitted_at DESC);
ALTER TABLE complaints ADD INDEX idx_priority_resolved (priority_id, resolved_at);
ALTER TABLE complaints ADD INDEX idx_officer_status (assigned_to, status);
```

### Accessibility (Keyboard-Only Navigation)

**ARIA Attributes:**
```html
<table role="grid" aria-label="Complaints table">
    <thead>
        <tr>
            <th role="columnheader" aria-sort="descending">
                Date <span aria-label="Sorted descending"</span>
            </th>
        </tr>
    </thead>
    <tbody>
        <tr role="row" tabindex="0" aria-selected="false">
            <td role="gridcell">CMP-2024-01234</td>
        </tr>
    </tbody>
</table>
```

**Focus Management:**
- Tab enters table (focus first row)
- Arrow keys navigate within table
- Enter activates row (opens detail panel)
- Escape closes panel, returns focus to table

---

## Prompt 12: Mobile App Experience (PWA)

### Overview
Convert web app to mobile-first PWA with native-like experience.

### PWA Manifest Structure

**`manifest.json`:**
```json
{
    "name": "Smart City Complaints",
    "short_name": "SmartCity",
    "description": "Report city issues and track resolution",
    "start_url": "/",
    "scope": "/",
    "display": "standalone",
    "theme_color": "#0f172a",
    "background_color": "#ffffff",
    "orientation": "portrait",
    "icons": [
        {
            "src": "/icons/icon-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "/icons/icon-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "any maskable"
        }
    ],
    "screenshots": [
        {
            "src": "/screenshots/screenshot-540x720.png",
            "sizes": "540x720",
            "type": "image/png"
        }
    ],
    "categories": ["government", "utilities"],
    "shortcuts": [
        {
            "name": "Report Issue",
            "short_name": "Report",
            "description": "Quickly report a city issue",
            "url": "/submit-complaint?utm_source=shortcut",
            "icons": [
                {
                    "src": "/icons/shortcut-report.png",
                    "sizes": "192x192"
                }
            ]
        }
    ]
}
```

### Service Worker Caching Strategy

**Stale-While-Revalidate:**
```javascript
// Cache-first with background update
self.addEventListener('fetch', (event) => {
    if (event.request.method === 'GET') {
        event.respondWith(
            caches.match(event.request)
                .then(response => {
                    if (response) {
                        // Update cache in background
                        fetch(event.request)
                            .then(updatedResponse => {
                                caches.open('api-cache-v1')
                                    .then(cache => cache.put(event.request, updatedResponse));
                            });
                        return response;
                    }
                    return fetch(event.request);
                })
        );
    }
});

// Network-first for API calls
if (event.request.url.includes('/api/')) {
    event.respondWith(
        fetch(event.request)
            .then(response => {
                caches.open('api-cache-v1').then(cache => cache.put(event.request, response));
                return response.clone();
            })
            .catch(() => caches.match(event.request))
    );
}
```

### Offline Data Sync Algorithm

**Key Concept:** Queue pending requests locally, sync when online

```javascript
class OfflineQueueManager {
    async queueAction(action) {
        // action: { type: 'POST', url: '/api/complaints', body: {...} }
        const db = await this.openIDB();
        const tx = db.transaction('pending_actions', 'readwrite');
        await tx.store.add({
            id: uuid(),
            ...action,
            timestamp: Date.now(),
            retries: 0
        });
    }
    
    async syncPendingActions() {
        if (!navigator.onLine) return;
        
        const db = await this.openIDB();
        const tx = db.transaction('pending_actions', 'readonly');
        const actions = await tx.store.getAll();
        
        for (const action of actions) {
            try {
                const response = await fetch(action.url, {
                    method: action.type,
                    body: JSON.stringify(action.body),
                    headers: { 'Content-Type': 'application/json' }
                });
                
                if (response.ok) {
                    await this.removeAction(action.id);
                } else if (action.retries < 3) {
                    action.retries++;
                    await this.updateAction(action);
                } else {
                    // Move to failed queue
                    await this.markActionFailed(action);
                }
            } catch (error) {
                if (action.retries < 3) {
                    action.retries++;
                    await this.updateAction(action);
                }
            }
        }
    }
    
    // Listen to online/offline events
    constructor() {
        window.addEventListener('online', () => this.syncPendingActions());
        window.addEventListener('offline', () => this.showOfflineIndicator());
    }
}
```

### Mobile Design Patterns

**Bottom Navigation (Thumb-friendly):**
```html
<nav class="bottom-nav" role="tablist">
    <a href="/complaints" class="nav-item active" role="tab">
        <svg><!-- home icon --></svg>
        <span>Home</span>
    </a>
    <a href="/report" class="nav-item" role="tab">
        <svg><!-- plus icon --></svg>
        <span>Report</span>
    </a>
    <a href="/status" class="nav-item" role="tab">
        <svg><!-- status icon --></svg>
        <span>Status</span>
    </a>
    <a href="/profile" class="nav-item" role="tab">
        <svg><!-- profile icon --></svg>
        <span>Profile</span>
    </a>
</nav>
```

**Gesture Interactions:**
```javascript
// Swipe to mark resolved
const swipeElement = document.querySelector('.complaint-card');
let startX = 0;

swipeElement.addEventListener('touchstart', (e) => {
    startX = e.touches[0].clientX;
});

swipeElement.addEventListener('touchend', (e) => {
    const endX = e.changedTouches[0].clientX;
    const diff =  startX - endX;
    
    if (diff > 100) {  // Swipe left > 100px
        markAsResolved(swipeElement.dataset.complaintId);
    }
});
```

**Pull to Refresh:**
- Drag down triggersrefresh
- Show spinner, fetch new data
- Snap back with animation

**Haptic Feedback:**
```javascript
// Vibrate on successful action
if (navigator.vibrate) {
    navigator.vibrate(50);  // 50ms buzz
}
```

### Performance Budget

| Metric | Target | Strategy |
|--------|--------|----------|
| Initial load | < 3s (4G) / < 5s (3G) | Code splitting, lazy load routes |
| Home screen install prompt | Shown within 30s | Prompt after 2nd visit |
| Offline first action | < 500ms | Optimistic updates, IndexedDB |
| Camera open (report) | < 2s | Native WebRTC, no libraries |
| JS bundle size | < 150KB | Tree-shake, polyfill on demand |
| CSS | < 50KB | Critical CSS inline, rest async |

---

## Prompt 13: Real-Time Collaboration Features

### Overview
Enable live cursors, mentions, activity feeds, presence indicators.

### Real-Time Architecture

**WebSocket vs SSE vs Long Polling:**

| Method | Latency | Bandwidth | Support | Use Case |
|--------|---------|-----------|---------|----------|
| WebSocket | <100ms | Good | All modern | Cursors, typing indicators |
| SSE | <1s | Better | Most | Activity feed, notifications |
| Long Polling | 1-5s | Poor | All | Fallback |

**Decision:** Use WebSocket for real-time, SSE for broadcasts

**Technology Stack:**
- Server: `python-socketio` (WebSocket server)
- Client: `socket.io-client` (browser)
- Message Bus: Redis (for scaling to multiple servers)

### State Synchronization Strategy

```javascript
class RealtimeCollaborationManager {
    constructor(complaintId, userId) {
        this.complaintId = complaintId;
        this.userId = userId;
        this.socket = io('/complaints', {
            auth: { complaint_id: complaintId, user_id: userId }
        });
        
        this.setupEventHandlers();
    }
    
    setupEventHandlers() {
        // Receive cursor positions
        this.socket.on('cursor_move', (data) => {
            this.renderRemoteCursor(data.userId, data.x, data.y, data.name);
        });
        
        // Someone is typing
        this.socket.on('typing', (data) => {
            this.showTypingIndicator(data.fieldName, data.userName);
        });
        
        // Field changed by someone else
        this.socket.on('field_updated', (data) => {
            this.handleRemoteFieldUpdate(data);
        });
        
        // Comment posted
        this.socket.on('comment_added', (data) => {
            this.adComment(data.comment);
        });
    }
    
    // Send cursor position
    moveCursor(x, y) {
        this.socket.emit('cursor_move', {
            x, y,
            fieldName: this.activeField
        });
    }
    
    // Send typing event
    updateField(fieldName, value) {
        this.socket.emit('field_changing', {
            fieldName,
            value  // Send partial updates
        });
    }
    
    // Handle remote field update with conflict resolution
    handleRemoteFieldUpdate(data) {
        const { fieldName, value, timestamp, userId } = data;
        const field = document.querySelector(`[data-field="${fieldName}"]`);
        
        // Conflict resolution: Last write wins (by timestamp)
        if (timestamp > this.lastLocalTimestamp[fieldName]) {
            // Remote is newer
            if (document.activeElement === field) {
                // User is editing locally - show conflict toast
                this.showMergeConflict(fieldName, value);
            } else {
                // Update field
                field.value = value;
                field.animate([
                    { backgroundColor: '#yellow' },
                    { backgroundColor: 'transparent' }
                ], { duration: 500 });
            }
        }
    }
    
    // Mention another user
    mentionUser(userId) {
        const mention = `@user_${userId}`;
        this.socket.emit('mention', { targetUserId: userId, text: this.textContent });
    }
}
```

### Conflict Resolution Patterns

**Last-Write-Wins (Simple):**
- Keep timestamp on each field
- Remote update with newer timestamp wins
- Pro: Simple, deterministic
- Con: Data loss for simultaneous edits

**Operational Transformation (Advanced):**
- Queue operations
- Rebase local ops against remote ops
- Maintain eventual consistency
- Pro: No data loss
- Con: Complex implementation

**Application-Level (Recommended):**
```javascript
// For our use case, explicit merging is safest
handleStatusConflict(remoteStatus, localStatus) {
    // Both trying to change status at same time
    // Ask user
    showMergeDialog({
        field: 'Status',
        current: localStatus,
        remote: remoteStatus,
        onResolve: (chosen) => {
            // User picks which wins
            updateField('status', chosen);
        }
    });
}
```

### Presence System Design

**User Presence Table:**
```sql
CREATE TABLE active_sessions (
    session_id VARCHAR(64) PRIMARY KEY,
    user_id INT UNSIGNED,
    complaint_id INT UNSIGNED,
    field_viewing VARCHAR(50),  -- which field/tab
    last_heartbeat TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id),
    KEY idx_complaint (complaint_id),
    KEY idx_user (user_id)
);
```

**Heartbeat + Cleanup:**
```python
# Send heartbeat every 30 seconds
@socketio.on('heartbeat')
def handle_heartbeat(data):
    update_session_last_heartbeat(session['session_id'])

# Clean up stale sessions every 5 minutes
@app.before_request
def cleanup_stale_sessions():
    query_db('''
        DELETE FROM active_sessions 
        WHERE last_heartbeat < NOW() - INTERVAL 2 MINUTE
    ''', commit=True)
```

**Render Presence Indicators:**
```javascript
// Show online users in complaint detail
const presenceData = await fetch(`/api/complaints/${id}/presence`);
const users = presenceData.json(); // [{user_id, name, color, field}]

users.forEach(user => {
    const avatar = createAvatarElement(user.name, user.color);
    const tooltip = `${user.name} is editing ${user.field}`;
    presenceBar.appendChild(avatar);
});
```

### Scaling to 100 Concurrent Users

**Single-Server:**
- Socket.io built-in, handles 100s easily
- Threshold: ~10,000 concurrent connections per server

**Multi-Server (Redis Adapter):**
```python
from python-socketio import AsyncServer, AsyncRedisManager

sio = AsyncServer(async_mode='asgi', client_manager=AsyncRedisManager('redis://localhost'))

# Now events broadcast across all servers
sio.emit('event', data, to=room)  # Goes to all servers
```

**Database Writes:**
- Batch analytics inserts (don't write per keystroke)
- Async: Queue events to background job processor (Celery/RQ)
- Rate limit: 1 write per field per 2 seconds

---

## Prompt 14: Accessibility & Internationalization

### Overview
WCAG 2.1 AA compliance + multi-language support (English, Hindi, Marathi).

### Accessibility Audit Checklist

**Perceivable:**
- [ ] Color contrast ≥ 4.5:1 for normal text, 3:1 for large text
- [ ] Alternative text for all images, icons
- [ ] Captions for videos
- [ ] Text can be resized without loss of function
- [ ] No information conveyed by color alone

**Operable:**
- [ ] Keyboard accessible: Tab, Enter, Arrow keys work
- [ ] Focus visible: 3px outline on all interactive elements
- [ ] Skip links: "Skip to main content"
- [ ] Form labels associated via `<label for>` or aria-label
- [ ] Autoplay disabled (or can be paused)
- [ ] No keyboard traps (can tab out)

**Understandable:**
- [ ] Language declared: `<html lang="en">`
- [ ] Page title descriptive
- [ ] Error messages clear: "Email field required"
- [ ] Form instructions paired with fields
- [ ] Consistent navigation pattern
- [ ] Abbreviations/acronyms explained on first use

**Robust:**
- [ ] Valid HTML + ARIA markup
- [ ] ARIA roles/properties/states used correctly
- [ ] Testing with screen readers (NVDA, JAWS)

### Translation Architecture (i18n)

**Library:** `i18next` (industry standard)

**File Structure:**
```
locales/
├─ en/
│  ├─ common.json
│  ├─ complaints.json
│  └─ admin.json
├─ hi/
│  ├─ common.json
│  └─ ...
└─ mr/
   └─ ...
```

**Example Translation File (`en/common.json`):**
```json
{
    "nav": {
        "home": "Home",
        "report": "Report Issue",
        "status": "Status Tracker"
    },
    "complaint": {
        "title": "Complaint {{id}}",
        "submitted_on": "Submitted on {{date, date}}",
        "days_open": "{{days}} days open",
        "estimated_fix": "Estimated fix: {{hours}} hours"
    }
}
```

**Backend i18n (Python):**
```python
from flask_babel import Babel, gettext, ngettext

babel = Babel(app)

@app.route('/api/categories')
def get_categories():
    rows = query_db('SELECT * FROM categories')
    return success([{
        'id': r['cat_id'],
        'name': gettext(r['cat_name']),  # Auto-translates
        'description': gettext(r['cat_description'])
    } for r in rows])

# In template
{{ gettext('Submit a complaint') }}
{{ ngettext('1 complaint', '{{ count }} complaints', count) }}
```

**Frontend Implementation:**
```javascript
import i18n from 'i18next';

i18n.init({
    lng: navigator.language.split('-')[0],  // en, hi, mr
    ns: ['common', 'complaints'],
    defaultNS: 'common',
    resources: {
        en: { common: enCommon, complaints: enComplaints },
        hi: { common: hiCommon, complaints: hiComplaints },
        mr: { common: mrCommon, complaints: mrComplaints }
    }
});

// Usage
const text = i18n.t('nav.home');  // "Home"
const days = i18n.t('complaint.estimated_fix', { hours: 24 });
```

**Language Switcher:**
```html
<select id="languageSelector">
    <option value="en">English</option>
    <option value="hi">हिंदी</option>
    <option value="mr">मराठी</option>
</select>

<script>
    document.getElementById('languageSelector').addEventListener('change', (e) => {
        i18n.changeLanguage(e.target.value);
        localStorage.setItem('language', e.target.value);
        location.reload();  // Or update UI dynamically
    });
</script>
```

### Testing Strategy for Screen Readers

**Tools:**
- NVDA (Windows, free)
- JAWS (expensive)
- macOS VoiceOver (built-in)
- ChromeVox (Chrome extension)

**Critical Flows to Test:**
1. Submit complaint form (navigate with screen reader only)
2. View complaint status (all info accessible)
3. Admin complaint management (table navigation)
4. Map interactions (zoom, pan, marker info)

**Test Script:**
```gherkin
Scenario: Submit complaint with screen reader
  Given NVDA screen reader is running
  When I navigate to /submit-complaint
  And I Tab through form fields
  Then I hear: "Complaint title, edit text"
  And I hear: "Describe issue, edit region"
  And field errors are announced: "Email required, error"
  And I hear: "Submit complaint, button"
```

### Cultural Considerations (Indian Users)

**Names:**
- Support 2-5 word names (not just first+last)
- Don't assume first name is forename

**Dates:**
- Format: DD/MM/YYYY (Indian standard)
- Indian holiday calendar support
- Monsoon season awareness

**Currency:**
- Use ₹ (rupee) symbol
- Indian numbering: ₹10,00,000 (ten lakhs)

**Locations:**
- Ward numbers, area names (not zip codes)
- State/district required

**Phone:**
- +91 prefix
- 10-digit mobile/landline distinction

**Typography:**
- Use fonts supporting Devanagari script: Noto Sans, Lato
- Separate font files for Latin + Hindi/Marathi
- Line-height: 1.8 for Devanagari (taller than Latin)

**Content Tone (Regional):**
- Hindi: Respectful, direct
- Marathi: Conversational, warm
- English: Professional, friendly

---

## Prompt 15: Performance & Scale Optimization

### Overview
Optimize for 100,000 users, 1 million complaints.

### Performance Budget Breakdown

| Component | Budget | How to Measure |
|-----------|--------|-----------------|
| Initial JS | < 120KB | Gzip size, bundleanalyzer.com |
| Initial CSS | < 40KB | Gzip size |
| Initial HTML | < 50KB | Uncompressed |
| Web fonts | < 200KB (all) | GTmetrix, Lighthouse |
| Images (hero) | < 150KB | Optimized WebP |
| Time to Interactive | < 3.5s | Lighthouse, WebPageTest |
| First Contentful Paint | < 1.8s | Lighthouse |
| Cumulative Layout Shift | < 0.1 | Lighthouse |

### Code Splitting Strategy

**By Route:**
```javascript
// webpack.config.js
const routes = [
    { path: '/submit-complaint', chunk: 'submit' },
    { path: '/status', chunk: 'status' },
    { path: '/admin', chunk: 'admin' }
];

// Load chunk only when navigating
router.on('navigate', (path) => {
    const chunk = routes.find(r => r.path === path).chunk;
    import(`./routes/${chunk}.js`);
});
```

**By Feature:**
```javascript
// Defer non-critical features
const mapLibrary = import('mapbox-gl');  // Lazy load

// Only load chart library if user clicks "Analytics"
document.getElementById('analyticsBtn').addEventListener('click', async () => {
    const { Chart } = await import('chart.js');
    new Chart(ctx, config);
});
```

### Image Optimization

**Format Selection:**
- JPEG: Photos (complaints before/after)
- WebP: Fallback for modern browsers
- SVG: Icons, logos
- AVIF: Latest (200KB → 50KB)

**Responsive Images:**
```html
<picture>
    <source srcset="/img/hero.avif" type="image/avif">
    <source srcset="/img/hero.webp" type="image/webp">
    <img src="/img/hero.jpg" alt="Smart City Hero">
</picture>

<!-- Responsive sizes -->
<img srcset="
    /img/complaint-small.webp 480w,
    /img/complaint-medium.webp 768w,
    /img/complaint-large.webp 1200w"
    sizes="(max-width: 480px) 100vw,
           (max-width: 768px) 90vw,
           85vw"
    src="/img/complaint-large.webp">
```

### Virtual Scrolling (Large Lists)

**Library:** `react-window` (React) or `virtual-scroll-core` (vanilla)

```javascript
// Only render visible rows
<FixedSizeList
    height={600}
    itemCount={10000}  // 10k rows possible
    itemSize={40}  // Each row 40px
    width="100%">
    {Row}
</FixedSizeList>
```

### Database Query Optimization

**Indexing Plan:**
```sql
-- Complaints table
ALTER TABLE complaints ADD INDEX idx_status_date (status, submitted_at DESC);
ALTER TABLE complaints ADD INDEX idx_dept_priority (dept_id, priority_id);
ALTER TABLE complaints ADD INDEX idx_location_cat (location_id, cat_id);

-- Users table
ALTER TABLE users ADD INDEX idx_role_active (role, is_active);

-- Crime incidents
ALTER TABLE crime_incidents ADD INDEX idx_date_location (incident_date DESC, location_id);
ALTER TABLE crime_incidents ADD INDEX idx_type_severity (crime_type_id, severity);
```

**Query Optimization Patterns:**

❌ Bad:
```sql
SELECT * FROM complaints;  -- Loads all columns
-- N+1: Loop and query department for each
```

✅ Good:
```sql
SELECT c.id, c.code, c.priority_id, c.status, d.dept_name
FROM complaints c
INNER JPG departments d ON c.dept_id = d.dept_id
WHERE c.submitted_at >= CURDATE() - INTERVAL 30 DAY
LIMIT 100;
```

### Caching Strategy

**Cache Layers:**
```
Browser Cache (Service Worker)
↓
CDN Cache (CloudFlare)
↓
Application Cache (Redis)
↓
Database Query Cache (MySQL)
↓
Database
```

**What to Cache:**

| Data | TTL | Strategy | Layer |
|------|-----|----------|-------|
| Categories list | 24h | Stale-while-revalidate | Redis + CDN |
| User profile | Session | Invalidate on update | Redis |
| Complaint detail | 5m | TTL | Redis |
| Lists (10 days old) | 1h | Stale-while-revalidate | CDN |
| Static JS/CSS | 30d | Versioned (hash in filename) | CDN |

**Redis Cache Warmer** (Pre-populate):
```python
def warm_cache():
    """Run daily at midnight"""
    categories = query_db('SELECT * FROM categories')
    redis.set('categories:all', json.dumps(categories), ex=86400)
    
    locations = query_db('SELECT * FROM locations')
    redis.set('locations:all', json.dumps(locations), ex=86400)
    
    # Pre-compute stats
    stats = {
        'total_complaints': query_db('SELECT COUNT(*) FROM complaints')[0],
        'resolved_today': query_db('''
            SELECT COUNT(*) FROM complaints 
            WHERE resolved_at >= CURDATE()
        ''')[0]
    }
    redis.set('dashboard:overview', json.dumps(stats), ex=3600)
```

### Monitoring & Alerting

**Key Metrics:**

```sql
-- Query response times
SELECT query, AVG(duration_ms), COUNT(*)
FROM slow_query_log
GROUP BY query
HAVING AVG(duration_ms) > 100
ORDER BY COUNT(*) DESC;
```

**Alerting Setup:**
```
Alert Chain:
├─ Response time > 500ms → Pagerduty (warning)
├─ Error rate > 1% → Slack (critical)
├─ Database connections > 80 → Email
└─ Disk usage > 80% → Email

Tools: Sentry (errors), DataDog (metrics), Grafana (dashboards)
```

**Frontend Monitoring (Sentry):**
```javascript
import * as Sentry from "@sentry/browser";

Sentry.init({
    dsn: 'https://...@sentry.io/project',
    tracesSampleRate: 0.1,  // Sample 10% for performance
});

// Track custom metrics
Sentry.captureMessage('Complaint submitted', 'info', {
    extra: { complaint_id: 567, category: 'Pothole' }
});
```

---

## Summary: Implementation Roadmap

### Phase 1 Priority Order
1. Sentiment analysis + auto-priority boost (Prompt 2)
2. AI categorization (Prompt 1)
3. Crime prediction (Prompt 4)
4. Predictive resolution time (Prompt 3)
5. Image recognition (Prompt 5)

### Phase 2 Priority Order
1. Landing page redesign (Prompt 6)
2. Dashboard redesign (Prompt 7)
3. Interactive map enhancement (Prompt 9)
4. Complaint submission gamification (Prompt 8)
5. Notifications system (Prompt 10)

### Phase 3 Priority Order
1. Mobile PWA (Prompt 12)
2. Admin power interface (Prompt 11)
3. Real-time collaboration (Prompt 13)
4. Performance optimization (Prompt 15)
5. Accessibility + i18n (Prompt 14)

---

## Database Schema Migration Order

```sql
-- Phase 1: AI Features
ALTER TABLE complaints ADD COLUMN (
    ai_suggested_category VARCHAR(100),
    ai_suggested_cat_id SMALLINT UNSIGNED,
    ai_confidence_score DECIMAL(3,2),
    sentiment_score DECIMAL(3,2),
    urgency_level ENUM('low','medium','high','critical'),
    auto_priority_boosted TINYINT(1),
    predicted_resolution_hours DECIMAL(5,2),
    photo_url VARCHAR(500),
    ai_detected_issue VARCHAR(150),
    photo_gps_lat DECIMAL(10,7),
    photo_gps_lng DECIMAL(10,7),
    gps_verified TINYINT(1)
);

-- Phase 2: Predictions & Analytics
CREATE TABLE crime_predictions (...)
CREATE TABLE resolution_predictions_log (...)
CREATE TABLE complaint_photos (...)
CREATE TABLE flagged_photos (...)

-- Phase 3: Real-time & Collaboration
CREATE TABLE active_sessions (...)
CREATE TABLE user_notification_preferences (...)
```

---

**This roadmap provides:**
- ✅ Database schema changes with SQL
- ✅ API endpoint specifications
- ✅ Architecture & algorithm explanations
- ✅ UI/UX design principles
- ✅ Implementation code snippets
- ✅ Performance optimization strategies
- ✅ Scalability planning
- ✅ Accessibility & i18n guidance

**Next Steps:**
1. Review this document with stakeholders
2. Prioritize features by business value
3. Create detailed tickets for each sub-task
4. Begin Phase 1 implementation (AI features)
5. Establish CI/CD pipeline for safe deployments
