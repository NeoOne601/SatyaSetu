
# FILE: apple_vision_server.py
# VERSION: 23.0.0
# PHASE: Phase 70.1 (APE Compiler Implementation)
# AUTHOR: SatyaSetu Principal Engineer
# DESCRIPTION: 
# 1. Replaced free-form inquiry logic with a strict Affordance Planning Engine.
# 2. Implemented zero-temperature JSON compilation for deterministic action chains.
# 3. Enforced strict input/output validation against the APE Schema.


import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoTokenizer, logging
from PIL import Image
import torch
import io, base64, json, time, os, gc
import threading

# Suppress warnings to maintain terminal clarity for machine-readable output
logging.set_verbosity_error()
os.environ["TOKENIZERS_PARALLELISM"] = "false"

app = FastAPI()
brain = {}
gpu_lock = threading.Lock()
is_reasoning = False

def initialize_brain():
    print("\n" + "="*60)
    print("   SATYA NEURAL HUB v23.0.0 - APE COMPILER")
    print("="*60)
    try:
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        dtype = torch.float16 if device == "mps" else torch.float32
        
        # 1. MOUNT RETINA (Florence-2)
        print("[HUB] Mounting Retina (Florence-2)...")
        brain['retina_p'] = AutoProcessor.from_pretrained('microsoft/Florence-2-base', trust_remote_code=True)
        brain['retina_m'] = AutoModelForCausalLM.from_pretrained(
            'microsoft/Florence-2-base', trust_remote_code=True, torch_dtype=dtype, 
            low_cpu_mem_usage=True
        ).to(device).eval()

        # 2. MOUNT CORTEX (Gemma-2-2b-it)
        print("[HUB] Mounting Cortex (Gemma-2-2b-it)...")
        brain['cortex_t'] = AutoTokenizer.from_pretrained('google/gemma-2-2b-it')
        brain['cortex_m'] = AutoModelForCausalLM.from_pretrained(
            'google/gemma-2-2b-it', torch_dtype=dtype, low_cpu_mem_usage=True
        ).to(device).eval()

        print(f"[SUCCESS] Hub Active on {device.upper()}. APE Logic Ready.")
        return True
    except Exception as e:
        print(f"[CRITICAL] Initialization Failed: {e}")
        return False

hub_ready = initialize_brain()

def validate_ape_output(data):
    """Verifies that the model output matches the required structured JSON schema."""
    try:
        if not isinstance(data.get("affordances"), list): return False
        for aff in data["affordances"]:
            if not all(k in aff for k in ["name", "confidence", "actions"]): return False
            if not isinstance(aff["actions"], list): return False
            for act in aff["actions"]:
                if not all(k in act for k in ["step", "instruction", "recordable"]): return False
        return True
    except:
        return False

def call_gemma_affordance_planner(structured_input):
    """Deterministic APE planner expanding object + context + attributes into checklists."""
    prompt = f"""You are an Affordance Planning Engine.

INPUT: a validated JSON object containing:
- object (label, confidence)
- context
- attributes
- allowed_affordances

OUTPUT: STRICT JSON only.
Do not explain.
Do not ask questions.
Do not add fields.

Rules:
- Use ONLY affordances from allowed_affordances.
- If uncertain, lower confidence.
- Each affordance must include 2–4 ordered actions.
- Actions must be concrete and observable.
- Mark each action as recordable true or false.

Example 1 — Tomato in Market
INPUT: {{
  "object": {{ "label": "tomato", "confidence": 0.97 }},
  "context": "market",
  "attributes": {{ "color": "red", "surface": "smooth" }},
  "allowed_affordances": ["buy", "inspect_quality"]
}}
OUTPUT: {{
  "object": {{ "label": "tomato", "confidence": 0.97 }},
  "context": "market",
  "affordances": [
    {{
      "name": "buy",
      "confidence": 0.92,
      "actions": [
        {{ "step": 1, "instruction": "Confirm price per kilogram with seller", "recordable": true }},
        {{ "step": 2, "instruction": "Select tomatoes without visible damage", "recordable": true }},
        {{ "step": 3, "instruction": "Complete payment", "recordable": false }}
      ]
    }},
    {{
      "name": "inspect_quality",
      "confidence": 0.88,
      "actions": [
        {{ "step": 1, "instruction": "Visually inspect tomato surface for bruises", "recordable": true }},
        {{ "step": 2, "instruction": "Check firmness by gentle pressing", "recordable": false }}
      ]
    }}
  ]
}}

Example 2 — Tomato at Home
INPUT: {{
  "object": {{ "label": "tomato", "confidence": 0.96 }},
  "context": "home",
  "attributes": {{ "color": "red" }},
  "allowed_affordances": ["cook", "nutrition"]
}}
OUTPUT: {{
  "object": {{ "label": "tomato", "confidence": 0.96 }},
  "context": "home",
  "affordances": [
    {{
      "name": "cook",
      "confidence": 0.95,
      "actions": [
        {{ "step": 1, "instruction": "Wash tomato under clean water", "recordable": true }},
        {{ "step": 2, "instruction": "Chop tomato using a knife", "recordable": true }}
      ]
    }},
    {{
      "name": "nutrition",
      "confidence": 0.78,
      "actions": [
        {{ "step": 1, "instruction": "Display nutritional information per 100 grams", "recordable": false }}
      ]
    }}
  ]
}}

INPUT: {json.dumps(structured_input)}
OUTPUT:"""

    with gpu_lock:
        inputs = brain['cortex_t'](prompt, return_tensors="pt").to(brain['cortex_m'].device)
        inputs = {k: v.to(torch.long) for k, v in inputs.items()}
        with torch.inference_mode():
            outputs = brain['cortex_m'].generate(**inputs, max_new_tokens=512, temperature=0.0)
            text = brain['cortex_t'].decode(outputs[0], skip_special_tokens=True)
            
        if torch.backends.mps.is_available(): torch.mps.empty_cache()

    try:
        json_str = text.split("OUTPUT:")[-1].strip()
        parsed = json.loads(json_str)
        if validate_ape_output(parsed):
            return parsed
        else:
            print(f"[APE_ERROR] Schema Mismatch: {json_str}")
    except Exception as e:
        print(f"[APE_ERROR] JSON Parse Error: {e} | Raw: {text}")
        
    return {
        "object": structured_input.get("object", {}),
        "context": structured_input.get("context", "unknown"),
        "affordances": []
    }

@app.post('/v1/vision')
async def vision(request: Request):
    global is_reasoning
    if is_reasoning: return Response(content='{"status": "BUSY"}', status_code=503)
    if not hub_ready: return Response(content="Hub Offline", status_code=503)
    
    start = time.time()
    try:
        payload = await request.json()
        image = Image.open(io.BytesIO(base64.b64decode(payload['images'][0]))).convert("RGB")
        with gpu_lock:
            with torch.inference_mode():
                inputs = brain['retina_p'](text="<DENSE_REGION_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
                if brain['retina_m'].dtype == torch.float16:
                    inputs['pixel_values'] = inputs['pixel_values'].to(torch.float16)
                generated_ids = brain['retina_m'].generate(input_ids=inputs["input_ids"], pixel_values=inputs["pixel_values"], max_new_tokens=64, num_beams=1)
                prediction = brain['retina_p'].post_process_generation(brain['retina_p'].batch_decode(generated_ids, skip_special_tokens=False)[0], task="<DENSE_REGION_CAPTION>", image_size=(image.width, image.height))
            if torch.backends.mps.is_available(): torch.mps.empty_cache()
        data = prediction["<DENSE_REGION_CAPTION>"]
        results = [{"label": l.upper(), "box_2d": [float(b[0]/image.width*1000), float(b[1]/image.height*1000), float(b[2]/image.width*1000), float(b[3]/image.height*1000)]} for l, b in zip(data['labels'], data['bboxes'])]
        print(f"[VISION] Tracking {len(results)} items | {time.time()-start:.2f}s")
        return {"response": json.dumps(results)}
    except Exception as e:
        return Response(content=str(e), status_code=500)
    finally:
        gc.collect()

@app.post('/v1/reason')
async def reason(request: Request):
    global is_reasoning
    is_reasoning = True
    try:
        payload = await request.json()
        result = call_gemma_affordance_planner(payload)
        return result
    except Exception as e:
        print(f"[ERROR] Reason crash: {e}")
        return {"affordances": []}
    finally:
        is_reasoning = False
        gc.collect()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)