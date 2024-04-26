const { MongoClient } = require('mongodb');
require('dotenv').config();
const sleep = require('util').promisify(setTimeout);

async function main() {
  // Current time for timestamp comparison
  const current_time = Date.now() / 1000;

  let local_conn_string = "mongodb://gateway.docker.internal:27017/";

  if (process.env.LOCAL_CONN) {
    local_conn_string = process.env.LOCAL_CONN;
  }

  console.log("Attempting to connect to:", local_conn_string);

  // Connection to local MongoDB
  const local_client = new MongoClient(local_conn_string);
  await local_client.connect();
  const local_db = local_client.db('cpu_memory_records'); // Change db name as needed
  const local_collection = local_db.collection('records');

  // Query to find recent records with high CPU usage
  const query = {
    timestamp: { $gte: current_time - 30 }, // Records in the last 30 seconds
    system_cpu_used: { $gt: 50 } // CPU usage greater than 50%
  };

  // Fetching records
  const records = await local_collection.find(query).toArray();
  console.log(records);

  const atlas_conn_string = process.env.REMOTE_CONN;
  if (!atlas_conn_string) {
    throw new Error("REMOTE_CONN environment variable not set");
  }

  // Connection to MongoDB Atlas
  const atlas_client = new MongoClient(atlas_conn_string);
  await atlas_client.connect();
  const atlas_db = atlas_client.db('cpu_memory_records'); // Change db name as needed
  const atlas_collection = atlas_db.collection('records');

  // Writing records to Atlas
  if (records.length > 0) {
    await atlas_collection.insertMany(records);
    console.log(`${records.length} records have been written to Atlas.`);
  } else {
    console.log("No records meet the criteria.");
  }

  // Close the database connections
  await local_client.close();
  await atlas_client.close();
}

// Running the main function repeatedly every 30 seconds
(async function() {
  while (true) {
    await main();
    await sleep(30000);
  }
})();

/*
const { MongoClient } = require("mongodb");

// Replace the uri string with your connection string.
const uri =
  "mongodb+srv://seanmtracey:FZW4U8HCprRpW8Ih@smt-bacalhau-mongo.xmaf0iv.mongodb.net/?retryWrites=true&w=majority&appName=smt-bacalhau-mongo";

const client = new MongoClient(uri);

console.log(client)

async function run() {
  try {
    await client.connect();

    const database = client.db('cpu_memory_records');
    const movies = database.collection('records');

    // Query for a movie that has the title 'Back to the Future'
    const query = {
        "timestamp": {"$exists": true},  //# Records in the last 30 seconds
    };
    const movie = await movies.findOne(query);

    console.log(movie);
  } finally {
    // Ensures that the client will close when you finish/error
    await client.close();
  }
}
run().catch(console.dir);
*/