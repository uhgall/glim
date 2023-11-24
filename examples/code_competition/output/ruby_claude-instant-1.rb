 ### library ( ruby )
# no lib needed

### problem specific code
require 'concurrent'

executor = Concurrent::CachedThreadPool.new

prompt2_analyze_code = -> do
  f(executor.post { Q(m1, prompt1_write_code) }, 
    executor.post { Q(m2, prompt1_write_code) },
    executor.post { Q(m3, prompt1_write_code) })
end

prompt3_summarize = -> do
  g(executor.post { prompt2_analyze_code.call }, 
    executor.post { prompt2_analyze_code.call })  
end

result = executor.post { prompt3_summarize.call }.await