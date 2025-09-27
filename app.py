from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Available devices (endpoints)
DEVICES = {
    "main_door": "Main Door",
    "workshop_room": "Workshop Room",
    "discussion_room": "Discussion Room"
}

@app.route("/<device>", methods=["POST"])
def control_device(device):
    if device not in DEVICES:
        return jsonify({"error": "Invalid device"}), 404

    data = request.get_json(force=True)
    action = data.get("action")
    visitor_name = data.get("visitor_name")
    user_name = data.get("user_name", "Unknown")

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_message = f"[{timestamp}] Device: {device}, Action: {action}, User: {user_name}, Visitor: {visitor_name}"
    
    print(log_message)

    return jsonify({
        "status": "success",
        "device": device,
        "action": action,
        "user": user_name,
        "visitor": visitor_name,
        "timestamp": timestamp
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
