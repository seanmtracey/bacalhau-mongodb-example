# Deploy a Multi-region ETL Pipeline with Bacalhau for MongoDB

In this guide, we will cover deploying, querying, and aggregating data in MongoDB databases.

You will need:

- [The Bacalhau CLI](https://docs.bacalhau.org/getting-started/installation)
- A UNIX-based Computer (macOS/Linux)
- [A Google Cloud account](https://cloud.google.com/)
- A Terminal
- [Terraform](https://www.terraform.io/)
- Git

## Overview

In this document, we'll be working through spinning up our own distributed network of databases across multiple regions of Google Cloud, and then applying the ETL ([Extract-Transform-Load](https://en.wikipedia.org/wiki/Extract,_transform,_load)) pattern to the data that is being stored in each location with Bacalhau.

### The Problem

- Lots of data is generated in lots of places
- Aggregating that in full can be expensive
- Processing that at each location can be logistically challenging

Why are we doing this? Well, modern infrastructure generates a lot of data in a lot of different places. Keeping tabs on where that data is, and accessing when you want to gain some insight can be both logistically complex, and expensive.

Typically, there are two approaches:

1. You can aggregate data from all of your data sources in a centralised location and perform queries on that new, larger datastore.

2. You can process that your data close to, or at the source of it's generation, and then aggregate the results somewhere else for further analysis.

Both approaches present challenges which aren't easy to overcome. When aggregating all of your data, there are multiple factors in play that can make the approach untenable: Cost of bandwidth, cost of centralised storage, time to execute queries and more.

Processing data the edge can tackle some of those issues, but it comes with it's own challenges. Namely: Tracking your infrastructure, communicating and executing remotely on those data sources, and having a consistent, repeatable way to manage each individual data source.

### The Solution

Enter [Bacalhau](https://bacalhau.org)! 

With Bacalhau, we can create a common interface for querying and filtering data at each source point, and then aggregate a reduced set of key data points for further analysis at a central location.

This tackles the problems presented by both typical appoaches. Instead of incurring fees transferring all of your data from your different sources, we only extract the data which we consider to be useful for any given application. 

For the first approach listed previously, this means less bandwidth and storage utilisation, and a smaller centralised data source from which we can derive greater insight into our data, faster.

For the second approach, we have a secure, consistent interface with which to execute processing on our data across the totality of our infrastructure, without having to consider the overhead of multi-regional, multi-cloud deployments.

## What are we going to build?

- An example infrastructure across 4 regions in a Google Cloud account:
    - Which sets up MongoDB at multiple locations across the world
    - Installs a small Python script on each instance which records system statistics and writes them to the local MongoDB instance.
    - And Installs Bacalhau at each location, creating a private cluster for compute execution
- Deploy a Bacalhau job at each location for processing data
- Filter that data at source for key datapoints
- Send that filtered data to MongoDB Atlas for aggregation and further analysis.

## Setup

### Installing Bacalhau

To run through this example, you'll first need to install the Bacalhau CLI tool on your local system. Follow [these instructions](https://docs.bacalhau.org/getting-started/) to get your local system setup, and then carry on with this example project.

This will enable you to interact with the private network that we'll be setting up with the Terraform script we've included with this project.

### Installing Terraform

As this project uses Terraform to build, deploy and manage the example infrastructure

### Setting up MongoDB Atlas

For this example project, we're going to be aggregating our filtered data in a [MongoDB Atlas](https://www.mongodb.com/atlas/database) database. We're using Atlas for this example, as it has an abundant free-tier that we can use to experiment and explore with, and given that we'll be coupling it with [MongoDB Community Edition](https://www.mongodb.com/try/download/community) in each of our deployed instances, we can keep the exact same data structure and interfaces to talk to both our centralised database, as well as those at the edge.

#### Creating a MongoDB Account

To get started, head over to the [MongoDB Atlas  home page](https://www.mongodb.com/atlas/database), and click the "Try Free" button. Follow the instructions in the form to create an account which will enable us to spin up a MongoDB Atlas deployment.

#### Creating a MongoDB Atlas Deployment

Once you've finished the sign-up process, you'll be taken to the "Overview" page for your new account. Click the "Create a deployment" button.

>>> IMAGE OF CREATE A DEPLOYMENT BUTTON

This will take you a form where you can deploy the database. For the purposes of this demo, 

1. Select the M0 type database
2. Give it a sensible name that you'll remember
3. Uncheck the 'Add sample dataset' box
4. Select your preffered cloud provider for hosting the database
    - This won't spin up anything in your account, the database will be created in MongoDB's account with your preffered provider.
5. Select a region for the instance to be deployed in.
    - You can choose any region you like, and it doesn't greatly matter which one you pick at this point, but try and pick something closest to your geographical location to reduce latency later when we're interacting with our stored data.

Once you've filled in the form, click "Create Deployment".

#### Adding a Database User 

Once the deployment process has finished, you'll be presented with a modal that will allow you to create a connection to your new Atlas instance. 

We don't need to do all of this quite at the moment, but copy the username and password presented in the form as the default user, and save them somewhere secure on your system. We'll need this information later. The click the "Create Database User" button. 

Once the user has been created, we don't need to follow the rest of the process at this point, so you can close the modal with the 'x' button at the top-right corner.

#### Enabling Access from the Internet

The last step in this process is enabling access to our Atlas database through the public internet. If you prefer, it's completely possible to specify the IP addresses of your instances for direct access after deploying the Terrafrom script, but as we don't know what our IP addresses are yet, we're just going to open it up to the public internet for access.

*Please note: This doesn't mean absolutely anybody on the internet will be able to access the data on our instance. Connections will still be secured over TLS and protected by the username/password combo we just saved.*

In the sidebar of the Atlas interface, click the "Network Access" tab.

You'll be taken to an overview page which will contain the IP address of the computer we just created our database from in a table.

To the top-right of that table, click the "ADD IP ADDRESS" button, and in the modal that appears, click "ALLOW ACCES FROM ANYWHERE", and then "Confirm".

Your MongoDB Atlas Database is now setup for access!

### Setting up a Google Cloud account

First, you need to install the Google Cloud SDK. Depending on your platform, you will need to install from a package manager, or directly compile. You can find the instructions to do so are here. [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)

After installing, you need to login to your Google Cloud account. [Full Instructions](https://cloud.google.com/sdk/docs/initializing). For most platforms, you should simply type:
```bash
gcloud auth login
```

After logging in, you need to create a project. [Full Instructions](https://cloud.google.com/resource-manager/docs/creating-managing-projects).

```bash
PROJECT_ID="my-project"
gcloud projects create $PROJECT_ID
```

You also need to get your billing account ID. 

```bash
gcloud beta billing accounts list
BILLING_ACCOUNT_ID="0136BA-110539-DCE35A"
```

Finally, you need to link the billing account to the project. [Full Instructions](https://cloud.google.com/billing/docs/how-to/modify-project).
  
```bash
gcloud beta billing projects link $PROJECT_ID --billing-account $BILLING_ACCOUNT_ID
```

Finally, you need to enable the compute API and storage API. [Full Instructions](https://cloud.google.com/apis/docs/getting-started).

```bash
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
```

This `$PROJECT_ID` will be used in the .env.json file in `project_id`.

## Deploying our Infrastructure

For this project, we're using Terraform to orchestrate our infrastructure. If you haven't done so already, now would be a good time to install Terraform on your local system. You can find instructions on that [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).

Our Terraform project defines and utilises a few key things to demonstrate an effective ETL pipeline with Bacalhau.

### Keys parts

1. 4 Google Cloud VPS
    - One instance located in London, Belgium, Singapore, and South Carolina
2. Terraform directory
    - A `cloud-init` script which will run on, and configure, each VPS as it spins up
    - A `node_files` directory which contains the service and shell scripts for generating entries in our local database and configuring our our private Bacalhau cluster.
    - `env.json` - a configuration file that we will add values to on our local system to help authenticate with, and configure our instances at deploy time.
3. `scripts` directory
    - The folder contains some Python scripts which will generate reports every 1/3 of a second on the status and utilisation of our servers. It's these reports that we'll be filtering down and extracting with the help of Bacalhau later on.

### Running our Terraform Script

Then, initialize Terraform. This will download the plugins needed to run the script.
```bash
cd terraform
terraform init
```

Then, run the script to plan the infrastructure.
```bash
terraform plan -out plan.out
```

This will show you what resources will be created. If you are happy with the plan, you can apply it.
```bash
terraform apply plan.out
```

Once that is completed, you will have a set of nodes that can communicate with each other. To destroy the infrastructure, run:
```bash
terraform destroy -plan=plan.out
```


### Deploying your Private Cluster

### Deploying a job on your Cluster

## Viewing the Results

## Additional Reading