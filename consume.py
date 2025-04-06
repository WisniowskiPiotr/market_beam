import pulsar

# Connect to the Pulsar broker (or proxy)
client = pulsar.Client('pulsar://192.168.49.2:32493') #31850 https://192.168.49.2:30631

# Create a consumer that subscribes to the topic
consumer = client.create_reader('persistent://public/default/my-topic', start_message_id=pulsar.MessageId.earliest)

# Receive messages in a loop
print("Waiting for messages...")
#consumer.seek(0)
while True:
    
    msg = consumer.read_next()
    print(f"Received: '{msg.data().decode('utf-8')}'")

# Clean up
consumer.close()
client.close()

#todo:
#https://pulsar.apache.org/docs/4.0.x/administration-pulsar-manager/#enable-jwt-authentication-optional

# secret to acess manager:  kubectl get secret -l component=pulsar-manager -o=jsonpath="{.items[0].data.UI_PASSWORD}" -n pulsar-namespace | base64 --decode
#user pulsar
