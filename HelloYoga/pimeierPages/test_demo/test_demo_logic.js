// logic.js for test_demo

// Example functions that could be bound to buttons
function primaryAction() {
    Pimeier.Toast.show("Primary Action Clicked!");
}

function secondaryAction() {
    Pimeier.Toast.show("Secondary Action Clicked!");
}

// Refresh logic
function onRefresh() {
    log("Refreshing...");
    viewModel.isRefreshing = true;
    render();
    
    // 模拟数据更新
    var newItem = { 
        title: "New Item " + Math.floor(Math.random() * 100), 
        subtitle: "Added via Refresh at " + new Date().toLocaleTimeString() 
    };
    
    // 插入到头部
    if (!viewModel.todoList) viewModel.todoList = [];
    viewModel.todoList.unshift(newItem);
    
    viewModel.isRefreshing = false;
    render();
    
    Pimeier.Toast.show("Refreshed! Added " + newItem.title);
    if (Pimeier.Device && Pimeier.Device.vibrate) {
        Pimeier.Device.vibrate();
    }
}

// Mock load more logic
function loadMore() {
    Pimeier.Toast.show("Loading more...");
}

// Add new task function
function addNewTask() {
    log("Adding new task...");
    if (!viewModel.todoList) viewModel.todoList = [];
    
    var newTask = {
        templateType: "item",
        title: "New Task " + Math.floor(Math.random() * 1000),
        subtitle: "Created at " + new Date().toLocaleTimeString()
    };
    
    viewModel.todoList.push(newTask);
    render();
    
    Pimeier.Toast.show("Task added: " + newTask.title);
    if (Pimeier.Device && Pimeier.Device.vibrate) {
        Pimeier.Device.vibrate();
    }
}
