# main.py
# Import the necessary libraries from the Firebase SDK
from firebase_functions import firestore_fn, options
from firebase_admin import initialize_app, firestore
import math

# Initialize the Firebase Admin SDK to interact with Firestore
initialize_app()

# Optional: Set the region for your functions for better performance
options.set_global_options(region="us-central1")

@firestore_fn.on_document_deleted("sessions/{sessionId}")
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
