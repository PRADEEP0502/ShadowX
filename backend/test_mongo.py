from pymongo import MongoClient

uri = "mongodb+srv://pradeep:Pradeep123@cluster0.6mujlyv.mongodb.net/?appName=Cluster0"

client = MongoClient(uri)

print(client.admin.command("ping"))