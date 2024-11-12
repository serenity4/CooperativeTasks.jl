# Examples

## Multi-threaded application architecture

An example use case that motivated the creation of this library is that of an application architecture that separates the rendering thread from the application thread.

The rendering thread submits work to the GPU to display visual elements, while the application thread processes user inputs and runs the application logic. The rendering thread may operate with a frequency somewhere around 60 Hz, while the application thread may operate faster or slower depending on reactivity requirements.

Both the rendering thread and application thread would use tasks spawned on different threads, with task migration turned off to prevent concurrency errors, particularly for certain GPU APIs which may have strong requirements in this regard for a number of API calls. For each frame, the rendering thread would ask the application thread to return the list of all visual elements to be rendered. When the user exits the application, the application thread would ask the rendering thread to shut down gracefully before shutting down itself, resulting in a smooth shutdown procedure.

For the purpose of testing, the application may be launched asynchronously, where the main thread spawns the application thread which in turn spawns the rendering thread. The main thread may schedule the execution of state-modifying functions by the application thread, before waiting for the application to finalize modifications and eventually perform a test on the application state. The main thread may monitor application and rendering tasks while waiting for processing to be done, before detaching and running its tests.
