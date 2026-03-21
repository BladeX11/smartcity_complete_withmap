import os
import joblib
import mysql.connector
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', 3306)),
    'user': os.environ.get('DB_USER', 'root'),
    'password': os.environ.get('DB_PASS', 'admin'),
    'database': os.environ.get('DB_NAME', 'smartcity_db')
}

MODEL_DIR = os.path.join(os.path.dirname(__file__), 'models')
os.makedirs(MODEL_DIR, exist_ok=True)
MODEL_PATH = os.path.join(MODEL_DIR, 'resolution_predictor.pkl')


def load_training_data():
    conn = mysql.connector.connect(**DB_CONFIG)
    query = """
    SELECT
      c.cat_id,
      c.location_id,
      c.priority_id,
      c.dept_id,
      DAYOFWEEK(c.submitted_at) AS day_of_week,
      MONTH(c.submitted_at) AS month_of_year,
      HOUR(c.submitted_at) AS hour_of_day,
      TIMESTAMPDIFF(HOUR, c.submitted_at, c.resolved_at) AS resolution_hours
    FROM complaints c
    WHERE c.resolved_at IS NOT NULL
      AND c.status IN ('resolved','closed')
      AND TIMESTAMPDIFF(HOUR, c.submitted_at, c.resolved_at) > 0
    LIMIT 5000
    """
    df = pd.read_sql(query, conn)
    conn.close()
    return df


def train_model(df: pd.DataFrame):
    if len(df) < 50:
        raise RuntimeError(f'Not enough resolved complaints for training: {len(df)}')

    feature_cols = ['cat_id', 'location_id', 'priority_id', 'dept_id', 'day_of_week', 'month_of_year', 'hour_of_day']
    target_col = 'resolution_hours'

    X = df[feature_cols]
    y = df[target_col]

    categorical_features = ['cat_id', 'location_id', 'priority_id', 'dept_id', 'day_of_week', 'month_of_year']
    numeric_features = ['hour_of_day']

    preprocessor = ColumnTransformer(
        transformers=[
            ('cat', OneHotEncoder(handle_unknown='ignore'), categorical_features),
            ('num', 'passthrough', numeric_features)
        ]
    )

    model = RandomForestRegressor(
        n_estimators=250,
        max_depth=14,
        min_samples_split=4,
        random_state=42,
        n_jobs=-1
    )

    pipeline = Pipeline([
        ('prep', preprocessor),
        ('model', model)
    ])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    pipeline.fit(X_train, y_train)
    pred = pipeline.predict(X_test)

    mae = mean_absolute_error(y_test, pred)
    r2 = r2_score(y_test, pred)

    metadata = {
        'mae_hours': float(mae),
        'r2_score': float(r2),
        'trained_rows': int(len(df)),
        'features': feature_cols
    }

    joblib.dump({'pipeline': pipeline, 'metadata': metadata}, MODEL_PATH)
    return metadata


if __name__ == '__main__':
    frame = load_training_data()
    metrics = train_model(frame)
    print('Model saved:', MODEL_PATH)
    print('MAE (hours):', round(metrics['mae_hours'], 2))
    print('R2:', round(metrics['r2_score'], 3))
