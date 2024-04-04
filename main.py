import pymongo
import random
import time
from datetime import datetime

# Connect to MongoDB
client = pymongo.MongoClient("mongodb://localhost:27017/")
db = client["cpu_memory_records"]
collection = db["records"]

# Function to generate mock CPU and memory records
def generate_mock_record():
	timestamp = datetime.now()
	cpu_percent = round(random.uniform(0, 100), 2)
	memory_percent = round(random.uniform(0, 100), 2)
	record = {
		"timestamp": timestamp,
		"cpu_percent": cpu_percent,
		"memory_percent": memory_percent
	}
	return record

# Generate 100 mock records and insert them into MongoDB
for _ in range(100):
	record = generate_mock_record()
	collection.insert_one(record)
	print("Inserted record:", record)
	time.sleep(1)  # Simulate time passing

print("Done inserting records.")
