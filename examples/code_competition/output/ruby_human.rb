
# library code - can be reused for other applications
class Future
  def initialize(&block)
    @thread = Thread.new(&block)
  end

  def value
    @thread.value
  end
end

####################
# code specific to problem

def Q(m, p)
  Future.new do
    # Define the asynchronous operation here
  end
end

p1 = # define p1
m1 = # define m1
m2 = # define m2

# Create futures for Q(m1, p1) and Q(m2, p1), will be evaluated in parallel
q1_p1 = Q(m1, p1)
q2_p1 = Q(m2, p1)

# Retrieve values and calculate p2; this blocks until both values are there
p2 = f(q1_p1.value, q2_p1.value)

# Create futures for Q(m1, p2) and Q(m2, p2), will be evaluated in parallel
q1_p2 = Q(m1, p2)
q2_p2 = Q(m2, p2)

# Retrieve values and calculate p3, blocks until both values are there
p3 = g(q1_p2.value, q2_p2.value)

# Calculate the final result
result = Q(m1, p3).value # blocks until value is there