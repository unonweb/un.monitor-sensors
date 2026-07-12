NOTES
=====

### CPU

**temp1**:
- The coretemp kernel driver numbers its sensors deterministically. 
- It registers the overall CPU package sensor first (temp1), followed sequentially by the individual hardware cores (temp2, temp3, etc.).

### NVME

**"Composite"**:
- The driver calculates a single Composite temperature using a weighted algorithm provided by the manufacturer. 
- It is designed to be the "source of truth" metric for throttling.
- If the drive gets too hot, it uses the Composite value to decide when to slow down to protect itself.
