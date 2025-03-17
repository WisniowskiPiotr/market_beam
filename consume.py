import pulsar

# Connect to the Pulsar broker (or proxy)
client = pulsar.Client('pulsar://192.168.49.2:30308') #31850

# Create a consumer that subscribes to the topic
consumer = client.subscribe('my-topic', subscription_name='my-subscription')

# Receive messages in a loop
print("Waiting for messages...")
consumer.seek(0)
while True:
    
    msg = consumer.receive()
    try:
        print(f"Received: '{msg.data().decode('utf-8')}'")
        consumer.acknowledge(msg)
    except Exception as e:
        consumer.negative_acknowledge(msg)

# Clean up
consumer.close()
client.close()
