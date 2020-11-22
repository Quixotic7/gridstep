# gridstep
**gridstep** is a polyphonic, isomorphic grid keyboard sequencer for monome norns + grid. 

![](doc/img/page_trig.png)

![](doc/img/grid_step_edit.png)

### requirements:

* **norns**
* **grid** - note input and sequencing

### optional:

* **external midi devices** - for getting more sounds than just Molly The Poly



### features

* The grid can be played in an isomorphic layout that is either chromatic or in-scale. 
* It can sequence up to 16 tracks. 
* Sequences are stored as grid positions rather than notes and can be recorded from the grid input or programmed in.
* Each track can send it's notes to the internal sound engine (Molly The Poly) or to any midi channel or device. 
* Each track can have up to 16 patterns that can be quickly changed individually or as scenes.
* Each pattern can have up to 16 bars and the length of a bar can be set between 1 step to 16 steps. By mixing up bar lengths, you can create interesting polyrhythms! 
* Each step can have trigger conditions to create dynamic patterns!
* Each step can have a different velocities and note lengths.
* Each step can be offset +- 12 substeps or 16 substeps if the pattern is in triplet mode.
* The entire project can be saved and projects can be loaded during playback.

### doc

documentation for **gridstep** can be found [here](doc/README.md).

### changelog

**v1.0.1** - fixed bug that could occur when changing the number of bars in a pattern.

**v1.0.1** - initial release


























