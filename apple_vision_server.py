# FILE: apple_vision_server.py
# VERSION: 19.0.0 (The Persistence Lockdown)
# AUTHOR: SatyaSetu Neural Architect
# FIX: Uses 'local_files_only' to stop 5GB re-downloads.
# FIX: Strictly casts pixels to half-precision to stop bias/type crashes.
# FIX: Implements aggressive cache clearing to prevent "Killed" OOM errors.

import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoTokenizer, logging
from PIL import Image
import torch
import io, base64, json, time, os, gc
import threading

# Suppress warnings and logs to keep terminal clean
logging.set_verbosity_error()
os.environ["TOKENIZERS_PARALLELISM"] = "false"

app = FastAPI()
brain = {}
gpu_lock = threading.Lock()

def load_brain():
    print("\n" + "="*60)
    print("   SATYA NEURAL HUB v19.0.0 - CACHE LOCKDOWN")
    print("="*60)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    dtype = torch.float16 if device == "mps" else torch.float32
    
    try:
        # 1. RETINA (Florence-2)
        print("[HUB] Loading Retina (Florence-2)...")
        # Attempt local load first to prevent 5GB re-downloads
        try:
            brain['retina_p'] = AutoProcessor.from_pretrained('microsoft/Florence-2-base', trust_remote_code=True, local_files_only=True)
            brain['retina_m'] = AutoModelForCausalLM.from_pretrained(
                'microsoft/Florence-2-base', trust_remote_code=True, torch_dtype=dtype, 
                low_cpu_mem_usage=True, local_files_only=True
            ).to(device).eval()
        except Exception:
            print("[WARN] Local load failed, checking for shards...")
            brain['retina_p'] = AutoProcessor.from_pretrained('microsoft/Florence-2-base', trust_remote_code=True)
            brain['retina_m'] = AutoModelForCausalLM.from_pretrained(
                'microsoft/Florence-2-base', trust_remote_code=True, torch_dtype=dtype, 
                low_cpu_mem_usage=True
            ).to(device).eval()

        # 2. CORTEX (Gemma-2-2b)
        print("[HUB] Loading Cortex (Gemma-2-2b)...")
        try:
            brain['cortex_t'] = AutoTokenizer.from_pretrained('google/gemma-2-2b-it', local_files_only=True)
            brain['cortex_m'] = AutoModelForCausalLM.from_pretrained(
                'google/gemma-2-2b-it', torch_dtype=dtype, 
                low_cpu_mem_usage=True, local_files_only=True
            ).to(device).eval()
        except Exception:
            print("[WARN] Local load failed for Cortex, verifying identity...")
            brain['cortex_t'] = AutoTokenizer.from_pretrained('google/gemma-2-2b-it')
            brain['cortex_m'] = AutoModelForCausalLM.from_pretrained(
                'google/gemma-2-2b-it', torch_dtype=dtype, low_cpu_mem_usage=True
            ).to(device).eval()

        print(f"[SUCCESS] Hub Online on {device.upper()}. Cache and Precision Locked.")
        return True
    except Exception as e:
        print(f"[CRITICAL] Loading Error: {e}")
        return False

# Initialize the models
hub_ready = load_brain()

@app.post('/v1/vision')
async def vision(request: Request):
    if not hub_ready: return Response(content="Hub Offline", status_code=503)
    start = time.time()
    try:
        payload = await request.json()
        image = Image.open(io.BytesIO(base64.b64decode(payload['images'][0]))).convert("RGB")
        
        with gpu_lock:
            with torch.inference_mode():
                # Task: High-Speed Box Detection
                inputs = brain['retina_p'](text="<DENSE_REGION_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
                
                # CRITICAL FIX: Explicit Precision Alignment
                if brain['retina_m'].dtype == torch.float16:
                    inputs['pixel_values'] = inputs['pixel_values'].to(torch.float16)

                generated_ids = brain['retina_m'].generate(input_ids=inputs["input_ids"], pixel_values=inputs["pixel_values"], max_new_tokens=64, num_beams=1)
                prediction = brain['retina_p'].post_process_generation(brain['retina_p'].batch_decode(generated_ids, skip_special_tokens=False)[0], task="<DENSE_REGION_CAPTION>", image_size=(image.width, image.height))
            
            # EVICT STALE TENSORS
            if torch.backends.mps.is_available(): 
                torch.mps.empty_cache()

        data = prediction["<DENSE_REGION_CAPTION>"]
        results = [{"label": l.upper(), "box_2d": [float(b[0]/image.width*1000), float(b[1]/image.height*1000), float(b[2]/image.width*1000), float(b[3]/image.height*1000)]} for l, b in zip(data['labels'], data['bboxes'])]

        print(f"[VISION] Pulse Handled | {time.time()-start:.2f}s")
        return {"response": json.dumps(results)}
    except Exception as e:
        print(f"[ERROR] Vision Exception: {e}")
        return Response(content=str(e), status_code=500)
    finally:
        gc.collect()

@app.post('/v1/reason')
async def reason(request: Request):
    start = time.time()
    try:
        payload = await request.json()
        obj = payload.get('object', 'Unknown')
        
        with gpu_lock:
            prompt = f"Object: {obj}. Scene: Physical verification. Suggest 3 short inquiries to learn more. Format as list with '?'."
            inputs = brain['cortex_t'](prompt, return_tensors="pt").to(brain['cortex_m'].device)
            # Ensure long tensor for token ids to prevent embedding mismatch
            inputs = {k: v.to(torch.long) for k, v in inputs.items()}

            with torch.inference_mode():
                outputs = brain['cortex_m'].generate(**inputs, max_new_tokens=80, temperature=0.7, do_sample=True)
                text = brain['cortex_t'].decode(outputs[0], skip_special_tokens=True)
            
            if torch.backends.mps.is_available(): torch.mps.empty_cache()
        
        lines = [l.strip() for l in text.replace(prompt, "").split("\n") if "?" in l][:3]
        if not lines: lines = [f"Usage of {obj}?", f"Origin of {obj}?", f"Value of {obj}?"]
        
        print(f"[REASON] Inquiries for {obj} synthesized.")
        return {"questions": lines}
    except Exception as e:
        print(f"[ERROR] Reasoning Exception: {e}")
        return {"questions": ["Context synthesis stuttered locally."]}
    finally:
        gc.collect()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)