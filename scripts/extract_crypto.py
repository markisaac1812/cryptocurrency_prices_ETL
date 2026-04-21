import requests
import os
from dotenv import load_dotenv
load_dotenv()

#api for getting all the crypto data in usd, with price change percentage in 1h
url = os.getenv("URL")
headers = {"x-cg-demo-api-key": os.getenv("COINGECKO_API_KEY")}
response = requests.get(url, headers=headers)
response.raise_for_status()  # Check if the request was successful
print(response.text)