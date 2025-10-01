# main.py
# Import the necessary libraries from the Firebase SDK
from firebase_functions import firestore_fn, options
from firebase_admin import initialize_app, firestore

# Initialize the Firebase Admin SDK to interact with Firestore
initialize_app()

# Optional: Set the region for your functions for better performance
options.set_global_options(region="africa-south1")

# <-- FIX: Added the 'document=' keyword argument
@firestore_fn.on_document_deleted(document="sessions/{sessionId}")
def on_session_deleted(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """
    Triggered when a document in the 'sessions' collection is deleted.
    This function finds and deletes all associated documents in the 'enrollments' collection.
    """

    # Get the ID of the deleted session from the event's parameters
    session_id = event.params["sessionId"]
    print(f"Session deleted: {session_id}. Starting cleanup of enrollments.")

    # Get a client instance for Firestore
    db = firestore.client()

    # Create a query to find all enrollment documents with the matching sessionId
    enrollments_ref = db.collection("enrollments")
    query = enrollments_ref.where(field_path="sessionId", op_string="==", value=session_id)
    
    # Execute the query and get all documents to be deleted
    docs_to_delete = list(query.stream())

    if not docs_to_delete:
        print("No associated enrollments found. Cleanup complete.")
        return

    print(f"Found {len(docs_to_delete)} enrollments to delete.")

    # Firestore limits batch writes to 500 operations. We must process the documents in chunks.
    batch_size = 500
    
    # Loop through the list of documents in chunks of 500
    for i in range(0, len(docs_to_delete), batch_size):
        # Get the next chunk of documents
        chunk = docs_to_delete[i:i + batch_size]
        
        # Create a new batch operation
        batch = db.batch()

        print(f"Processing batch with {len(chunk)} documents.")
        
        # Add a delete operation for each document in the chunk to the batch
        for doc in chunk:
            batch.delete(doc.reference)
        
        # Commit the batch to execute the deletions
        batch.commit()
    
    print(f"Successfully deleted all {len(docs_to_delete)} enrollments.")


# <-- FIX: Added the 'document=' keyword argument
@firestore_fn.on_document_created(document="conversations/{conversationId}/messages/{messageId}")
def on_message_create(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """
    Triggered when a new message is created. Increments the unread message 
    count for all participants except the sender, correctly identifying their role.
    """
    
    message_data = event.data.after.to_dict()
    if message_data is None:
        print("No data in the new message.")
        return

    conversation_id = event.params["conversationId"]
    sender_id = message_data.get("senderId")
    if not sender_id:
        print(f"Message {event.params['messageId']} is missing a senderId.")
        return

    db = firestore.client()
    conv_ref = db.collection("conversations").document(conversation_id)
    conv_doc = conv_ref.get()

    if not conv_doc.exists:
        print(f"Conversation document {conversation_id} not found.")
        return

    participants = conv_doc.to_dict().get("participantIds", [])
    batch = db.batch()

    for participant_id in participants:
        if participant_id != sender_id:
            collection_name = None
            # <-- MODIFIED: Check the ID prefix to determine the user's role/collection
            if participant_id.startswith("stu_"):
                collection_name = "students"
            elif participant_id.startswith("lec_"):
                collection_name = "lecturers"
            elif participant_id.startswith("adm_"): # Assuming admin IDs start with 'adm_'
                collection_name = "administrators"

            if collection_name:
                user_ref = db.collection(collection_name).document(participant_id)
                batch.update(user_ref, {
                    "unreadMessagesCount": firestore.Increment(1)
                })
            else:
                print(f"Could not determine collection for participant ID: {participant_id}")

    batch.commit()
    print(f"Incremented message count for recipients in conversation {conversation_id}.")
