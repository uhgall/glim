```ruby
### library ( ruby )

require 'concurrent'

class Q
  def initialize(m, action)
    @future = Concurrent::Future.execute do
      m.send(action)
    end
  end

  def result
    @future.value
  end
end

### problem specific code

def f(*actions)
  actions.map(&:result)
end

def g(*actions)
  actions.map(&:result)
end

prompt2_analyze_code = f( Q.new(m1, :prompt1_write_code), Q.new(m2, :prompt1_write_code), Q.new(m3, :prompt1_write_code)) 
prompt3_summarize = g( Q.new(m1, :prompt2_analyze_code), Q.new(m2, :prompt2_analyze_code)) 
result = Q.new(m1, :prompt3_summarize).result
```