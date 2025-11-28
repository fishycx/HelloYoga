// logic.js for test_demo

// If viewModel is not defined, we will let PimeierVC inject it from JSON.
// If we define it here as {}, it will override JSON data because JS runs first.
// So we remove the initialization.

// However, if we want to add methods to viewModel later, we need to ensure it exists?
// No, methods are global functions in Pimeier logic.js.
// viewModel is just data.

// Example functions that could be bound to buttons
function primaryAction() {
    Pimeier.Toast.show("Primary Action Clicked!");
}

function secondaryAction() {
    Pimeier.Toast.show("Secondary Action Clicked!");
}

// Mock refresh logic
function refresh() {
    Pimeier.Toast.show("Refreshing...");
    // In a real app, this would fetch data and update viewModel
}

// Mock load more logic
function loadMore() {
    Pimeier.Toast.show("Loading more...");
}
