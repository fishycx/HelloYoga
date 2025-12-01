// logic.js for test_demo

// 初始化：获取系统音量和亮度
function initSystemSettings() {
    // 获取当前亮度
    Pimeier.System.getBrightness()
        .then(function(brightness) {
            // 将 0-1 转换为 0-100
            var brightnessPercent = Math.round(brightness * 100);
            log("当前亮度: " + brightnessPercent + "%");
            
            // 更新 todoList 中亮度 slider 的值
            if (viewModel.todoList) {
                for (var i = 0; i < viewModel.todoList.length; i++) {
                    if (viewModel.todoList[i].id === "slider_brightness") {
                        viewModel.todoList[i].sliderValue = brightnessPercent;
                        break;
                    }
                }
            }
        })
        .catch(function(error) {
            log("获取亮度失败: " + error);
        });
    
    // 获取当前音量
    Pimeier.System.getVolume()
        .then(function(volume) {
            // 将 0-1 转换为 0-100
            var volumePercent = Math.round(volume * 100);
            log("当前音量: " + volumePercent + "%");
            
            // 更新 todoList 中音量 slider 的值
            if (viewModel.todoList) {
                for (var i = 0; i < viewModel.todoList.length; i++) {
                    if (viewModel.todoList[i].id === "slider_volume") {
                        viewModel.todoList[i].sliderValue = volumePercent;
                        break;
                    }
                }
            }
        })
        .catch(function(error) {
            log("获取音量失败: " + error);
        });
}

// 页面加载完成后初始化系统设置
// 注意：这个函数会在 viewModel 注入后自动调用
// 使用立即执行函数，在 viewModel 可用时自动初始化
(function() {
    function tryInit() {
        if (typeof viewModel !== 'undefined' && viewModel.todoList) {
            initSystemSettings();
        } else {
            // 如果 viewModel 还未准备好，延迟重试
            setTimeout(tryInit, 50);
        }
    }
    tryInit();
})();

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

// Switch change handler
function onSwitchChange(id, value) {
    log("Switch changed: id=" + id + ", value=" + value);
    
    // 注意：双向绑定已经更新了 item.switchValue，这里只需要更新 viewModel.todoList（如果需要）
    // 实际上，由于双向绑定已经更新了 item.switchValue，而 item 是 todoList 中项的引用，
    // 所以数据已经同步了，不需要再次更新
    
    // 显示 Toast
    var status = value ? "已开启" : "已关闭";
    Pimeier.Toast.show("开关 " + id + " " + status);
    
    // 注意：不要调用 render()，因为双向绑定已经更新了值，控件本身已经显示了正确的状态
    // 如果确实需要更新其他依赖该值的 UI 元素，可以在这里调用 render()
    // 但对于 Switch 和 Slider 这种交互式控件，通常不需要立即重新渲染整个页面
}

// Slider change handler
function onSliderChange(id, value) {
    log("Slider changed: id=" + id + ", value=" + value);
    
    // 注意：双向绑定已经更新了 item.sliderValue，这里只需要处理业务逻辑
    // 不需要再次更新数据或调用 render()
    
    // 根据 id 调用不同的系统功能
    if (id === "slider_volume") {
        // 音量调节：将 0-100 转换为 0-1
        var volume = value / 100.0;
        Pimeier.System.setVolume({ value: volume })
            .then(function(result) {
                log("音量设置成功: " + volume);
            })
            .catch(function(error) {
                log("音量设置失败: " + error);
                Pimeier.Toast.show("音量设置失败: " + error);
            });
    } else if (id === "slider_brightness") {
        // 亮度调节：将 0-100 转换为 0-1
        var brightness = value / 100.0;
        Pimeier.System.setBrightness({ value: brightness })
            .then(function(result) {
                log("亮度设置成功: " + brightness);
            })
            .catch(function(error) {
                log("亮度设置失败: " + error);
                Pimeier.Toast.show("亮度设置失败: " + error);
            });
    }
    
    // 注意：不要调用 render()，因为双向绑定已经更新了值，控件本身已经显示了正确的状态
    // 如果需要更新显示的数值文本，可以在这里调用 render()
    // 但对于 Slider 这种频繁交互的控件，通常不需要立即重新渲染整个页面
}
