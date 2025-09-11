import os
import sys
from twelvedata import TDClient
import pandas as pd

def fetch_forex_data(api_key, symbol="EUR/USD", interval="1h", outputsize=10):
    """
    Fetches historical forex data from Twelve Data.

    Args:
        api_key (str): Your Twelve Data API key.
        symbol (str): The symbol of the forex pair (e.g., "EUR/USD").
        interval (str): The time interval (e.g., "1min", "5min", "1h", "4h", "1day").
        outputsize (int): The number of data points to retrieve.

    Returns:
        pandas.DataFrame: A DataFrame containing the OHLC data, or None if an error occurs.
    """
    try:
        # Initialize Twelve Data client
        td = TDClient(apikey=api_key)

        # Request time series data
        ts = td.time_series(
            symbol=symbol,
            interval=interval,
            outputsize=outputsize,
        )

        # Convert to pandas DataFrame
        df = ts.as_pandas()
        return df

    except Exception as e:
        print(f"An error occurred: {e}")
        return None

if __name__ == "__main__":
    # --- IMPORTANT ---
    # For this script to work, you must get a free API key from Twelve Data
    # and set it as an environment variable named 'TWELVE_DATA_API_KEY'.
    #
    # You can register for a free key here: https://twelvedata.com/register
    #
    # How to set an environment variable:
    # On Linux/macOS: export TWELVE_DATA_API_KEY='your_key_here'
    # On Windows: set TWELVE_DATA_API_KEY='your_key_here'

    api_key = os.getenv("TWELVE_DATA_API_KEY")

    if not api_key:
        print("ERROR: Twelve Data API key not found.")
        print("Please get a free API key from https://twelvedata.com/register")
        print("Then set it as an environment variable named 'TWELVE_DATA_API_KEY'.")
        sys.exit(1)

    print("Fetching data for EUR/USD...")
    forex_df = fetch_forex_data(api_key=api_key, symbol="EUR/USD", interval="1h", outputsize=12)

    if forex_df is not None:
        print("Successfully fetched data:")
        print(forex_df)
    else:
        print("Failed to fetch data. Please check your API key and network connection.")
