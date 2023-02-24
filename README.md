# TaskGroupError

If you are using the composable architecture and you need to send actions back into the store from a TaskGroup, in particular, if those actions use DependencyValues (causing the send method in the run effect to use TaskLocals from within your TaskGroup--something that is illegal), then you need a different way of sending those actions out of the task group. This repo suggests a pattern for accomplishing that via the AsyncChannel type available from the AsyncAlgorithms package. 
