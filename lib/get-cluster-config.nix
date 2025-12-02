lib:
cluster:
lib.filterAttrsRecursive (n: v: 
    n != "modules"
    && n != "libraryofalexandria"  # somehow this gets looped in (maybe the 'with' keyword?)
) cluster