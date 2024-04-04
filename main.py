import pymongo
import random
import time
import psutil
import time

p = psutil.Process()

# Connect to MongoDB
client = pymongo.MongoClient("mongodb://localhost:27017/")
db = client["cpu_memory_records"]
collection = db["records"]

# Function to generate mock CPU and memory records
def generate_record(cpuUsage, memUsage):
	
	timestamp = time.time()
	cpu_percent = cpuUsage
	memory_percent = memUsage

	record = {
		"timestamp": timestamp,
		"cpu_used": cpu_percent,
		"memory_used": memory_percent
	}
	
	return record

while True:
	cpu_percentage = psutil.cpu_percent(percpu=False)
	memory_percent = psutil.virtual_memory().percent
	
	record = generate_record(cpu_percentage, memory_percent)

	if cpu_percentage == 0.0:
		continue

	print(record["cpu_used"], record["memory_used"])

	collection.insert_one(record)

	time.sleep(1 / 3)
