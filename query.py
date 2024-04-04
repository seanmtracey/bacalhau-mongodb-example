import pymongo
import json
from datetime import datetime

# Connect to MongoDB
client = pymongo.MongoClient("mongodb://localhost:27017/")
db = client["cpu_memory_records"]
collection = db["records"]

# Function to query records within a time range
def query_records(query_str):
    query_dict = json.loads(query_str)

    print(query_dict)

    records = collection.find(query_dict)
    return list(records)

# Example: Query records with a string representation of the query
query_str = '{"cpu_percent": {"$gte": 50}, "memory_percent" : {"$gte" : 50}}'  # Example query as string
result = query_records(query_str)

# Print the queried records
print("Records with query:", query_str)
for record in result:
    print(record)
