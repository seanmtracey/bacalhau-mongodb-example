from pymongo import MongoClient
import time, os

def main():
    # Current time for timestamp comparison
    current_time = time.time()

    local_conn_string = "mongodb://gateway.docker.internal:27017/"

    if os.getenv('LOCAL_CONN'):
        local_conn_string = os.getenv('LOCAL_CONN')

    # Connection to local MongoDB
    local_client = MongoClient(local_conn_string)
    local_db = local_client['cpu_memory_records']  # Change db name as needed
    local_collection = local_db['records']

    # Query to find recent records with high CPU usage
    query = {
        "timestamp": {"$gte": current_time - 30},  # Records in the last 30 seconds
        "system_cpu_used": {"$gt": 50}  # CPU usage greater than 75%
    }

    # Fetching records
    records = list(local_collection.find(query))

    print(records)

    atlas_conn_string = os.getenv('REMOTE_CONN')
    if not atlas_conn_string:
        raise EnvironmentError("REMOTE_CONN environment variable not set")

    # Connection to MongoDB Atlas
    atlas_client = MongoClient(atlas_conn_string)  # Include your Atlas connection string here
    atlas_db = atlas_client['cpu_memory_records']  # Change db name as needed
    atlas_collection = atlas_db['records']

    # Writing records to Atlas
    if records:
        atlas_collection.insert_many(records)
        print(f"{len(records)} records have been written to Atlas.")
    else:
        print("No records meet the criteria.")

if __name__ == '__main__':
    while True:
        main()
        time.sleep(30)
