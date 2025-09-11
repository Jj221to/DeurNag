import os
import sys
from flask import Flask, jsonify, render_template

# Adjust the path to import from the parent directory
# This allows us to import the data_fetcher module
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from data_fetcher import fetch_forex_data

# Initialize the Flask application
app = Flask(__name__)

@app.route('/')
def index():
    """
    Renders the main dashboard page from the 'templates' folder.
    """
    return render_template('index.html')

@app.route('/api/data')
def get_forex_data_api():
    """
    API endpoint to fetch and return forex data as JSON.
    """
    api_key = os.getenv("TWELVE_DATA_API_KEY")
    if not api_key:
        return jsonify({"error": "API key not found. Please set the TWELVE_DATA_API_KEY environment variable."}), 500

    # Fetch data using our existing function
    data = fetch_forex_data(api_key=api_key, symbol="EUR/USD", interval="1h", outputsize=24)

    if data is not None:
        # Convert DataFrame to a list of records (dictionaries)
        # The datetime index needs to be converted to a string.
        data['datetime'] = data.index.strftime('%Y-%m-%d %H:%M:%S')
        data_json = data.to_dict(orient='records')
        return jsonify(data_json)
    else:
        return jsonify({"error": "Failed to fetch data from the provider."}), 500

if __name__ == '__main__':
    # Runs the Flask development server.
    # In a production environment, a proper WSGI server like Gunicorn would be used.
    # Host '0.0.0.0' makes it accessible from outside the container.
    app.run(debug=True, host='0.0.0.0', port=8080)
