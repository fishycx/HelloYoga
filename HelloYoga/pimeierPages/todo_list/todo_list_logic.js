var viewModel = {
    title: "My Tasks (JS)",
    inputText: "",
    todos: [
        { title: "Learn Swift" },
        { title: "Master Yoga" },
        { title: "Build Pimeier" }
    ]
};

function addTodo() {
    // 调用原生震动 (演示 Bridge)
    if (Pimeier && Pimeier.Device) {
        Pimeier.Device.vibrate().then(function() {
            log("📳 Vibrated");
        });
    }
    
    log("Try adding todo, current input: '" + viewModel.inputText + "'");
    
    var text = viewModel.inputText;
    
    if (text && text.length > 0) {
        // 添加新任务
        viewModel.todos.push({ title: text });
        log("✅ Added task: " + text);
        
        // 打印设备信息 (演示异步调用)
        if (Pimeier && Pimeier.Device) {
            Pimeier.Device.getInfo().then(function(info) {
                log("📱 Device Info: " + JSON.stringify(info));
            });
        }
        
        // 清空输入
        viewModel.inputText = "";
        
        // 触发重绘
        render();
    } else {
        log("⚠️ Input is empty");
        // 使用原生 Toast 替代 alert (演示 Bridge)
        if (Pimeier && Pimeier.Toast) {
            Pimeier.Toast.show("⚠️ Please enter a task name (Native Toast)");
        } else {
            alert("Please enter a task name");
        }
    }
}

function removeTodo(index) {
    log("Removing task at index: " + index);
    if (index >= 0 && index < viewModel.todos.length) {
        viewModel.todos.splice(index, 1);
        render();
    }
}

log("Todo Logic Loaded");
