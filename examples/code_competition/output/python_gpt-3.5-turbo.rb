### library ( python )
```python
import threading

class Q:
    def __init__(self, caller, func):
        self.caller = caller
        self.func = func
        self.result = None
        self.thread = None
        self.lock = threading.Lock()

    def __call__(self, *args, **kwargs):
        if self.result is None:
            with self.lock:
                if self.result is None:
                    self.thread = threading.Thread(target=self.execute, args=args, kwargs=kwargs)
                    self.thread.start()
        self.thread.join()
        return self.result

    def execute(self, *args, **kwargs):
        self.result = self.func(*args, **kwargs)

def f(*args, **kwargs):
    return sum(args)

def g(*args, **kwargs):
    return sum(args)
```

### problem specific code
```python
m1 = "John"
m2 = "Jane"
m3 = "David"

prompt1_write_code = "Write code"

prompt2_analyze_code = f(Q(m1, prompt1_write_code), Q(m2, prompt1_write_code), Q(m3, prompt1_write_code))
prompt3_summarize = g(Q(m1, prompt2_analyze_code), Q(m2, prompt2_analyze_code))
result = Q(m1, prompt3_summarize)
```