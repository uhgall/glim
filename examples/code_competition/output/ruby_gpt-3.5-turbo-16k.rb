### library (ruby)

No library is needed for this problem.

### problem specific code

```ruby
def Q(module_name, statement)
  # Code to make API call and return the result
  # (Assuming implementation for making API call is already done)
end

def f(*statements)
  # Code to process multiple statements asynchronously
end

def g(*statements)
  # Code to process multiple statements asynchronously
end

# Example usage
prompt2_analyze_code = f(Q(:m1, Q(:prompt1_write_code)), Q(:m2, Q(:prompt1_write_code)), Q(:m3, Q(:prompt1_write_code)))
prompt3_summarize = g(Q(:m1, prompt2_analyze_code), Q(:m2, prompt2_analyze_code))
result = Q(:m1, prompt3_summarize)
```

Note: The implementation of making API calls and processing statements asynchronously is not provided as it is specific to the API being used and the requirements of processing the statements.