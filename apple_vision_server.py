#FILE: apple_vision_server.py
#VERSION: 28.0.0
#PHASE: Phase 76.1 (Handover Protocol Release)
#AUTHOR: SatyaSetu Principal Engineer
#DESCRIPTION: 
#1. Real-Time Vision: /v1/vision is now lean (boxes only) to ensure <1s tracking.
#2. Handover Logic: Supports a separate /v1/reason call to prevent GPU deadlock.
#3. Cache Stability: Uses local_files_only=True to prevent 5GB metadata corruption cycles.
#4. Precision Guard: Strictly casts pixels to float16 for iMac MPS compatibility.


import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoTokenizer, logging
from PIL import Image
import torch
import io, base64, json, time, os, gc
import threading

# Suppress library logs for clean machine-readable output
logging.set_verbosity_error()
os.environ["TOKENIZERS_PARALLELISM"] = "false"

app = FastAPI()
brain = {}
gpu_lock = threading.Lock()

def load_brain():
    print("\n" + "="*60)
    print("   SATYA NEURAL HUB v28.0.0 - HANDOVER MODE")
    print("="*60)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    dtype = torch.float16 if device == "mps" else torch.float32
    
    try:
        # LOCAL LOCKDOWN: Prevent corruption/re-downloads
        print("[HUB] Mounting Retina (Florence-2) [Local]...")
        brain['retina_p'] = AutoProcessor.from_pretrained('microsoft/Florence-2-base', trust_remote_code=True, local_files_only=True)
        brain['retina_m'] = AutoModelForCausalLM.from_pretrained(
            'microsoft/Florence-2-base', trust_remote_code=True, torch_dtype=dtype, 
            low_cpu_mem_usage=True, local_files_only=True
        ).to(device).eval()

        print("[HUB] Mounting Cortex (Gemma-2-2b) [Local]...")
        brain['cortex_t'] = AutoTokenizer.from_pretrained('google/gemma-2-2b-it', local_files_only=True)
        brain['cortex_m'] = AutoModelForCausalLM.from_pretrained(
            'google/gemma-2-2b-it', torch_dtype=dtype, 
            low_cpu_mem_usage=True, local_files_only=True
        ).to(device).eval()

        print(f"[SUCCESS] Hub Online on {device.upper()}. State locks active.")
        return True
    except Exception as e:
        print(f"[CRITICAL] Loading Error: {e}")
        return False

hub_ready = load_brain()

@app.post('/v1/vision')
async def vision(request: Request):
    """High-speed object tracking endpoint (<1s latency)."""
    if not hub_ready: return Response(content="Hub Offline", status_code=503)
    start = time.time()
    try:
        payload = await request.json()
        image = Image.open(io.BytesIO(base64.b64decode(payload['images'][0]))).convert("RGB")
        
        with gpu_lock:
            with torch.inference_mode():
                # PERCEPTION ONLY
                inputs = brain['retina_p'](text="<DENSE_REGION_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
                if brain['retina_m'].dtype == torch.float16:
                    inputs['pixel_values'] = inputs['pixel_values'].to(torch.float16)
                
                generated_ids = brain['retina_m'].generate(input_ids=inputs["input_ids"], pixel_values=inputs["pixel_values"], max_new_tokens=64, num_beams=1)
                prediction = brain['retina_p'].post_process_generation(brain['retina_p'].batch_decode(generated_ids, skip_special_tokens=False)[0], task="<DENSE_REGION_CAPTION>", image_size=(image.width, image.height))
            
            if torch.backends.mps.is_available(): torch.mps.empty_cache()

        data = prediction["<DENSE_REGION_CAPTION>"]
        results = [{"label": l.upper(), "box_2d": [float(b[0]/image.width*1000), float(b[1]/image.height*1000), float(b[2]/image.width*1000), float(b[3]/image.height*1000)]} for l, b in zip(data['labels'], data['bboxes'])]

        print(f"[VISION] Handled {len(results)} items in {time.time()-start:.2f}s")
        return {"response": json.dumps(results)}
    except Exception as e:
        print(f"[ERROR] Vision Pulse Crash: {e}")
        return Response(content=str(e), status_code=500)
    finally:
        gc.collect()

@app.post('/v1/reason')
async def reason(request: Request):
    """Deep APE planning endpoint (Invoked only on tap)."""
    start = time.time()
    try:
        payload = await request.json()
        obj = payload.get("object", {}).get("label", "Unknown")
        ctx = payload.get("context", "general")
        allowed = payload.get("allowed_affordances", [])

        print(f">>> GEMMA_PROMPT_PAYLOAD: Compiling plan for {obj}")
        
        prompt = f"""You are an Affordance Planning Engine. Output STRICT JSON only.
INPUT: {{"object": "{obj}", "context": "{ctx}", "allowed": {allowed}}}
OUTPUT: {{"affordances": [{{"name": "...", "confidence": 0.9, "actions": [{{"step": 1, "instruction": "...", "recordable": true}}]}}]}}
OUTPUT:"""

        with gpu_lock:
            inputs = brain['cortex_t'](prompt, return_tensors="pt").to(brain['cortex_m'].device)
            inputs = {k: v.to(torch.long) for k, v in inputs.items()}
            
            with torch.inference_mode():
                outputs = brain['cortex_m'].generate(**inputs, max_new_tokens=256, temperature=0.0)
                text = brain['cortex_t'].decode(outputs[0], skip_special_tokens=True)
                
            if torch.backends.mps.is_available(): torch.mps.empty_cache()
            
        print("<<< GEMMA_RAW_RESPONSE:", text)
        json_str = text.split("OUTPUT:")[-1].strip()
        return json.loads(json_str)
    except Exception as e:
        print(f"[APE_ERROR] Fallback: {e}")
        return {"affordances": []}
    finally:
        gc.collect()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)