# FILE: apple_vision_server.py
# VERSION: 13.0.0 (The Reactive Pulse Release)
# DESCRIPTION: Orchestrates Florence-2 and Gemma-2 in FP16.
# FIX: Suppresses batch_size warnings and implements aggressive memory purging.
# FIX: Explicitly casts image tensors to float16 to prevent bias-mismatch crashes.

import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoTokenizer, logging
from PIL import Image
import torch
import io, base64, json, time, os, gc
import threading

# Suppress deprecation warnings to keep terminal clean
logging.set_verbosity_error()
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

app = FastAPI()
brain = {}
gpu_lock = threading.Lock()

def initialize_brain():
    print("\n" + "="*50)
    print("   SATYA NEURAL HUB v13.0.0 - REACTIVE MODE")
    print("="*50)
    try:
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        dtype = torch.float16 if device == "mps" else torch.float32
        
        # 1. MOUNT RETINA (Florence-2)
        print("[HUB] Mounting Retina (Florence-2) in FP16...")
        retina_id = 'microsoft/Florence-2-base'
        brain['retina_p'] = AutoProcessor.from_pretrained(retina_id, trust_remote_code=True)
        brain['retina_m'] = AutoModelForCausalLM.from_pretrained(
            retina_id, trust_remote_code=True, torch_dtype=dtype,
            low_cpu_mem_usage=True
        ).to(device).eval()
        
        # 2. MOUNT CORTEX (Gemma-2-2b)
        print("[HUB] Mounting Cortex (Gemma-2-2b) in FP16...")
        cortex_id = 'google/gemma-2-2b-it'
        brain['cortex_t'] = AutoTokenizer.from_pretrained(cortex_id)
        brain['cortex_m'] = AutoModelForCausalLM.from_pretrained(
            cortex_id, trust_remote_code=True, torch_dtype=dtype,
            low_cpu_mem_usage=True
        ).to(device).eval()
        
        print(f"[SUCCESS] Hub Active on {device.upper()}. Memory Guards Engaged.")
        return True
    except Exception as e:
        print(f"[CRITICAL] Hub failed: {e}")
        return False

status = initialize_brain()

@app.post('/v1/vision')
async def vision(request: Request):
    start = time.time()
    try:
        payload = await request.json()
        image = Image.open(io.BytesIO(base64.b64decode(payload['images'][0]))).convert("RGB")
        
        with gpu_lock:
            with torch.inference_mode():
                # Task: Pure Perception (No heavy captioning to maintain real-time)
                inputs = brain['retina_p'](text="<DENSE_REGION_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
                
                # CRITICAL FIX: Ensure inputs are Half-Precision to match model
                if brain['retina_m'].dtype == torch.float16:
                    inputs['pixel_values'] = inputs['pixel_values'].to(torch.float16)

                generated_ids = brain['retina_m'].generate(input_ids=inputs["input_ids"], pixel_values=inputs["pixel_values"], max_new_tokens=64, num_beams=1)
                prediction = brain['retina_p'].post_process_generation(brain['retina_p'].batch_decode(generated_ids, skip_special_tokens=False)[0], task="<DENSE_REGION_CAPTION>", image_size=(image.width, image.height))
            
            # AGGRESSIVE CACHE CLEARING
            if torch.backends.mps.is_available(): 
                torch.mps.empty_cache()
                torch.mps.synchronize()

        data = prediction["<DENSE_REGION_CAPTION>"]
        results = [{"label": data['labels'][i].upper(), "box_2d": [float(data['bboxes'][i][0]/image.width*1000), float(data['bboxes'][i][1]/image.height*1000), float(data['bboxes'][i][2]/image.width*1000), float(data['bboxes'][i][3]/image.height*1000)]} for i in range(len(data['bboxes']))]

        print(f"[VISION] Handled {len(results)} items | Latency: {time.time()-start:.2f}s")
        return {"response": json.dumps(results), "context": "Physical context detected."}
    except Exception as e:
        print(f"[ERROR] Vision Pulse Crash: {e}")
        return Response(content=str(e), status_code=500)

@app.post('/v1/reason')
async def reason(request: Request):
    start = time.time()
    try:
        payload = await request.json()
        obj = payload.get('object', 'Unknown')
        
        with gpu_lock:
            prompt = f"Object: {obj}. Context: Local physical inspection. Suggest 3 short, intriguing inquiries a user might ask. Format as list with '?'."
            inputs = brain['cortex_t'](prompt, return_tensors="pt").to(brain['cortex_m'].device)
            
            # Ensure long tensors for token IDs
            for k in inputs: inputs[k] = inputs[k].to(torch.long)

            with torch.inference_mode():
                outputs = brain['cortex_m'].generate(**inputs, max_new_tokens=80)
                text = brain['cortex_t'].decode(outputs[0], skip_special_tokens=True)
            
            if torch.backends.mps.is_available(): torch.mps.empty_cache()
        
        lines = [l.strip() for l in text.replace(prompt, "").split("\n") if "?" in l][:3]
        if not lines: lines = [f"Origin of {obj}?", f"Value of {obj}?", f"Physicality of {obj}?"]
        
        print(f"[REASON] Inquiries for {obj} synthesized.")
        return {"questions": lines}
    except Exception as e:
        print(f"[ERROR] Reason Pulse Crash: {e}")
        return {"questions": ["Context synthesis failed locally."]}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)