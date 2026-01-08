# FILE: apple_vision_server.py
# VERSION: 40.0.0
# PHASE: Phase 87.1 (Industrial Recovery)
# AUTHOR: SatyaSetu Principal Engineer
# DESCRIPTION: 
# 1. Optimized Pulse: Florence detection optimized for <0.5s inference.
# 2. Server-Side Resize: Offloaded heavy pixel work from Dart to Python/PIL.
# 3. Serialized GPU Access: Strict locks prevent Metal context-switching deadlock.
# 4. Watchdog Logging: Full telemetry for prompt payloads and raw LLM output.

import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoTokenizer, logging
from PIL import Image
import torch
import io, base64, json, time, os, gc
import threading
from concurrent.futures import ThreadPoolExecutor, TimeoutError

# Suppress library noise for diagnostic clarity
logging.set_verbosity_error()
os.environ["TOKENIZERS_PARALLELISM"] = "false"

app = FastAPI()
brain = {}
gpu_lock = threading.Lock()
executor = ThreadPoolExecutor(max_workers=1)

def load_brain():
    print("\n" + "="*60)
    print("   SATYA NEURAL HUB v40.0.0 - INDUSTRIAL STABILITY")
    print("="*60)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    dtype = torch.float16 if device == "mps" else torch.float32
    
    try:
        print("[HUB] Mounting Retina (Florence-2)...")
        brain['retina_p'] = AutoProcessor.from_pretrained('microsoft/Florence-2-base', trust_remote_code=True)
        brain['retina_m'] = AutoModelForCausalLM.from_pretrained(
            'microsoft/Florence-2-base', trust_remote_code=True, torch_dtype=dtype, 
            low_cpu_mem_usage=True, attn_implementation="eager"
        ).to(device).eval()

        # NOTE: Skipping Gemma to save MPS memory - affordances computed locally in Flutter
        print("[HUB] Skipping Cortex (Gemma) - local affordances enabled.")

        print(f"[SUCCESS] Hub Online on {device.upper()}. Vision-only mode.")
        return True
    except Exception as e:
        print(f"[CRITICAL] Loading Error: {e}")
        return False

hub_ready = load_brain()

def _run_gemma_logic(payload):
    """Processes structured APE plans. Isolated in watchdog thread."""
    obj = payload.get("object", {}).get("label", "Unknown")
    print(f">>> GEMMA_INVOKED: Planning for {obj}")
    print(">>> GEMMA_PROMPT_PAYLOAD:", json.dumps(payload, indent=2))

    # Simplified prompt for faster generation
    prompt = f'''For object "{obj}", suggest 2 practical actions.
Format: {{"affordances": [{{"name": "action", "confidence": 0.9, "actions": [{{"step": 1, "instruction": "do X", "recordable": true}}]}}]}}
Output valid JSON only:'''

    try:
        with gpu_lock:
            inputs = brain['cortex_t'](prompt, return_tensors="pt").to(brain['cortex_m'].device)
            inputs = {k: v.to(torch.long) for k, v in inputs.items()}
            with torch.inference_mode():
                outputs = brain['cortex_m'].generate(
                    **inputs, 
                    max_new_tokens=200,  # Reduced for speed
                    temperature=0.1, 
                    do_sample=True,
                    use_cache=False  # FIX: Prevent MPS cache issues
                )
                text = brain['cortex_t'].decode(outputs[0], skip_special_tokens=True)
            
            if torch.backends.mps.is_available(): torch.mps.empty_cache()
            print("<<< GEMMA_RAW_RESPONSE:", text[:500])
            
            # Extract JSON from response
            import re
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
            return None
    except Exception as e:
        print(f"[APE_ERROR] Reasoning failure: {e}")
        return None

@app.post('/v1/vision')
async def vision(request: Request):
    """LEAN TRACKER: Objects only (<0.8s latency)."""
    if not hub_ready: return Response(content="Hub Offline", status_code=503)
    start = time.time()
    try:
        payload = await request.json()
        img_b64 = payload.get('images', [None])[0]
        if not img_b64:
            print("[WARN] Empty image payload received")
            return {"response": "[]"}
        
        try:
            image = Image.open(io.BytesIO(base64.b64decode(img_b64))).convert("RGB")
        except Exception as decode_err:
            print(f"[ERROR] Image decode failed: {decode_err}")
            return {"response": "[]"}
        
        print(f"[DEBUG] Image received: {image.width}x{image.height}")
        
        # OFF-LOADED RESIZE: Fast C-based thumbnailing
        if image.width > 640:
            image.thumbnail((448, 448))

        with gpu_lock:
            with torch.inference_mode():
                inputs = brain['retina_p'](text="<DENSE_REGION_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
                if brain['retina_m'].dtype == torch.float16:
                    inputs['pixel_values'] = inputs['pixel_values'].to(torch.float16)
                
                generated_ids = brain['retina_m'].generate(
                    input_ids=inputs["input_ids"], 
                    pixel_values=inputs["pixel_values"], 
                    max_new_tokens=64, 
                    num_beams=1, 
                    do_sample=True,
                    temperature=0.1,
                    use_cache=False  # FIX: Bypass past_key_values bug in Florence-2 cached model
                )
                prediction = brain['retina_p'].post_process_generation(brain['retina_p'].batch_decode(generated_ids, skip_special_tokens=False)[0], task="<DENSE_REGION_CAPTION>", image_size=(image.width, image.height))
            
            if torch.backends.mps.is_available(): torch.mps.empty_cache()

        # Defensive: Handle case where prediction is malformed
        dense_data = prediction.get("<DENSE_REGION_CAPTION>", {})
        labels = dense_data.get('labels', [])
        bboxes = dense_data.get('bboxes', [])
        
        results = []
        for l, b in zip(labels, bboxes):
            results.append({"label": l.upper(), "box_2d": [float(b[0]/image.width*1000), float(b[1]/image.height*1000), float(b[2]/image.width*1000), float(b[3]/image.height*1000)]})

        print(f"[VISION] Handled {len(results)} items in {time.time()-start:.2f}s")
        return {"response": json.dumps(results)}
    except Exception as e:
        import traceback
        print(f"[ERROR] Vision Pulse failure: {e}")
        traceback.print_exc()
        return Response(content=str(e), status_code=500)
    finally:
        gc.collect()

@app.post('/v1/reason')
async def reason(request: Request):
    """APE Planner: Called only on user interaction."""
    try:
        payload = await request.json()
        future = executor.submit(_run_gemma_logic, payload)
        result = future.result(timeout=30.0) # 30s Watchdog for MPS
        print(f"<<< GEMMA_RETURNED: Planning complete.")
        return result or {"affordances": []}
    except TimeoutError:
        print("[WARN] GEMMA_TIMEOUT: Sending fallback.")
        return {"affordances": []}
    except Exception as e:
        print(f"[ERROR] Reason failure: {e}")
        return {"affordances": []}
    finally:
        gc.collect()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)