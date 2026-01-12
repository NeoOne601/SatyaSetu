# FILE: admin_portal/backend/main.py
# VERSION: 1.0.0
# ROLE: Admin Portal Backend (Indexer Simulation)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import random
import time

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simulated ClickHouse Data
@app.get("/api/analytics/velocity")
def get_velocity():
    """Returns real-time transaction velocity per sector."""
    return {
        "timestamp": time.time(),
        "sectors": [
            {"name": "Transport", "tps": random.randint(50, 120), "trend": "up"},
            {"name": "Civic", "tps": random.randint(10, 30), "trend": "stable"},
            {"name": "Trade", "tps": random.randint(200, 450), "trend": "up"},
        ]
    }

# Simulated Neo4j Graph Data
@app.get("/api/analytics/graph")
def get_graph_nodes():
    """Returns nodes for the 3D Graph Visualization."""
    nodes = []
    links = []
    for i in range(20):
        nodes.append({"id": f"node_{i}", "group": random.randint(1, 3), "val": random.randint(5, 20)})
        if i > 0:
            links.append({"source": f"node_{i}", "target": f"node_{random.randint(0, i-1)}"})
    return {"nodes": nodes, "links": links}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)