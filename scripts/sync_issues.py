import os
import json
import firebase_admin
from firebase_admin import credentials, firestore
import requests

def sync_reports():
    # 1. Initialize Firebase
    service_account_info = json.loads(os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON'))
    cred = credentials.Certificate(service_account_info)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    # 2. Get GitHub info
    github_token = os.environ.get('GITHUB_TOKEN')
    repo_name = os.environ.get('GITHUB_REPOSITORY')
    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json"
    }

    # 3. Sync Bug Reports
    _sync_collection(db, 'bug_reports', repo_name, headers, ["bug", "in-app-report"], "[App Report]")

    # 4. Sync Product Ideas
    _sync_collection(db, 'product_ideas', repo_name, headers, ["product-idea", "in-app-report"], "[Product Idea]")

def _sync_collection(db, collection_name, repo_name, headers, labels, title_prefix):
    ref = db.collection(collection_name)
    unsynced = ref.where('synced', '==', False).stream()

    for doc in unsynced:
        data = doc.to_dict()
        doc_id = doc.id
        
        title = data.get('title', 'No Title')
        description = data.get('description', 'No Description')
        user_id = data.get('userId', 'anonymous')
        device = data.get('deviceName', 'unknown')
        os_ver = data.get('osVersion', 'unknown')
        app_ver = data.get('appVersion', 'unknown')
        
        body = f"""
## {title_prefix.strip('[] ')} Details
**User ID:** {user_id}
**Device:** {device}
**OS:** {os_ver}
**App Version:** {app_ver}

### Description
{description}
        """

        issue_url = f"https://api.github.com/repos/{repo_name}/issues"
        issue_data = {
            "title": f"{title_prefix} {title}",
            "body": body,
            "labels": labels
        }
        
        response = requests.post(issue_url, headers=headers, json=issue_data)
        
        if response.status_code == 201:
            print(f"Successfully synced {collection_name} {doc_id} to GitHub.")
            ref.document(doc_id).update({'synced': True})
        else:
            print(f"Failed to sync {collection_name} {doc_id}. Status: {response.status_code}")
            print(response.text)

if __name__ == "__main__":
    if not os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON'):
        print("Error: FIREBASE_SERVICE_ACCOUNT_JSON not set.")
    elif not os.environ.get('GITHUB_TOKEN'):
        print("Error: GITHUB_TOKEN not set.")
    else:
        sync_reports()
