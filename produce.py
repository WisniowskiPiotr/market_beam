import pulsar

# Connect to the Pulsar broker (or proxy)
client = pulsar.Client('pulsar://192.168.49.2:31627')

# Create a producer for a topic
producer = client.create_producer('persistent://public/default/my-topic')

# Send a few messages
for i in range(10):
    message = f"Hello Pulsar! Message {i} new"
    producer.send(message.encode('utf-8'))
    print(f"Sent: {message}")

# Close the client
producer.close()
client.close()
