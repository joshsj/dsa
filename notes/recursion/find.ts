// left and right are optional
type N = { value: number, left?: N, right?: N };

// haystack is optional
function find(needle: number, haystack: N | undefined): N | undefined {
    // base case handles the optionality
    if (!haystack) {
        return undefined;
    }

    if (needle < haystack.value) {
        // pass left, delegate undefined check to base case
        return find(needle, haystack.left);
    }

    if (needle > haystack.value) {
        // same again
        return find(needle, haystack.right);
    }

    return haystack;
}
