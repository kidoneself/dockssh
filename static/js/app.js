// DockSSH 前端应用
// API 基础 URL
const API_BASE = '';

// 全局状态
let currentPage = 'home';
let currentConnectionId = null;
let currentTemplate = null;
let currentDockerApp = null;
let terminal = null;
let terminalSocket = null;
let connections = [];
let sudoPassword = ''; // 存储 sudo 密码（仅内存中）
let isBatchMode = false; // 是否处于批量选择模式
let selectedApps = []; // 已选中的应用列表

// ===== 页面导航 =====

function showPage(pageName) {
    // 隐藏所有页面
    document.querySelectorAll('.page').forEach(page => {
        page.classList.remove('active');
    });
    
    // 显示目标页面
    document.getElementById(`page-${pageName}`).classList.add('active');
    
    // 更新导航菜单
    document.querySelectorAll('.nav-menu a').forEach(link => {
        link.classList.remove('active');
    });
    document.querySelector(`[data-page="${pageName}"]`).classList.add('active');
    
    currentPage = pageName;
    
    // 加载页面数据
    loadPageData(pageName);
}

function loadPageData(pageName) {
    switch(pageName) {
        case 'ssh':
            loadSSHConfigs();
            break;
        case 'templates':
            loadTemplates();
            break;
        case 'docker':
            loadDockerApps();
            break;
        case 'terminal':
            loadConnections();
            initTerminal();
            break;
    }
}

// ===== 工具函数 =====

function showToast(message, type = 'info') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast show ${type}`;
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

function showModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

async function apiCall(url, method = 'GET', data = null) {
    const options = {
        method,
        headers: {
            'Content-Type': 'application/json',
        },
    };
    
    if (data) {
        options.body = JSON.stringify(data);
    }
    
    // 增加超时控制（60秒）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 60000);
    options.signal = controller.signal;
    
    try {
        const response = await fetch(API_BASE + url, options);
        clearTimeout(timeoutId);
        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.detail || '请求失败');
        }
        
        return result;
    } catch (error) {
        clearTimeout(timeoutId);
        if (error.name === 'AbortError') {
            throw new Error('请求超时，请检查网络连接');
        }
        console.error('API 调用失败:', error);
        throw error;
    }
}

// ===== 快速连接 =====

async function quickConnect() {
    const host = document.getElementById('quick-host').value;
    const port = document.getElementById('quick-port').value;
    const username = document.getElementById('quick-username').value;
    const password = document.getElementById('quick-password').value;
    
    if (!host || !username || !password) {
        showToast('请填写所有连接信息', 'error');
        return;
    }
    
    try {
        const result = await apiCall('/api/ssh/connect', 'POST', {
            host,
            port: parseInt(port),
            username,
            password
        });
        
        currentConnectionId = result.connection_id;
        updateConnectionStatus(true, `${username}@${host}`);
        
        // 自动保存 sudo 密码（SSH 密码通常就是 sudo 密码）
        sudoPassword = password;
        showToast('连接成功！正在打开终端...', 'success');
        
        // 清空表单
        document.getElementById('quick-password').value = '';
        
        // 刷新连接列表
        await loadConnections();
        
        // 自动打开悬浮终端
        setTimeout(() => {
            openFloatingTerminal();
            // 等待终端初始化后自动连接
            setTimeout(() => {
                const floatingSelect = document.getElementById('floating-connection-select');
                if (floatingSelect && currentConnectionId) {
                    floatingSelect.value = currentConnectionId;
                    autoConnectTerminal();
                }
            }, 500);
        }, 300);
        
    } catch (error) {
        showToast(`连接失败: ${error.message}`, 'error');
    }
}

let lastConnectionConfigId = null; // 保存最后连接的配置ID

function updateConnectionStatus(isConnected, info = '') {
    const indicator = document.getElementById('connection-indicator');
    const text = document.getElementById('connection-text');
    const reconnectBtn = document.getElementById('reconnect-btn');
    
    if (isConnected) {
        indicator.className = 'status-dot online';
        text.textContent = info;
        if (reconnectBtn) {
            reconnectBtn.style.display = 'inline-block';
        }
    } else {
        indicator.className = 'status-dot offline';
        text.textContent = '未连接';
        if (reconnectBtn) {
            reconnectBtn.style.display = 'none';
        }
    }
}

async function reconnectSSH() {
    if (!lastConnectionConfigId) {
        showToast('没有可重连的配置', 'error');
        return;
    }
    
    showToast('正在重新连接...', 'info');
    
    try {
        // 断开当前连接
        if (currentConnectionId) {
            try {
                await apiCall(`/api/ssh/connections/${currentConnectionId}`, 'DELETE');
            } catch (e) {
                console.log('断开旧连接失败（可能已断开）');
            }
        }
        
        // 关闭终端WebSocket
        if (terminalSocket) {
            terminalSocket.close();
            terminalSocket = null;
        }
        
        // 重新连接
        await connectSSHConfig(lastConnectionConfigId);
        
    } catch (error) {
        showToast(`重连失败: ${error.message}`, 'error');
    }
}

// ===== SSH 配置管理 =====

async function loadSSHConfigs() {
    try {
        const result = await apiCall('/api/ssh/configs');
        const container = document.getElementById('ssh-configs-list');
        
        if (result.configs.length === 0) {
            container.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">暂无配置</p>';
            return;
        }
        
        container.innerHTML = result.configs.map(config => `
            <div class="config-card">
                <div class="config-info">
                    <h3>${config.name}</h3>
                    <div class="config-details">
                        <span>🌐 ${config.host}:${config.port}</span>
                        <span>👤 ${config.username}</span>
                        <span>🔐 ${config.auth_type === 'password' ? '密码' : '私钥'}</span>
                    </div>
                </div>
                <div class="config-actions">
                    <button onclick="connectSSHConfig('${config.id}')" class="btn btn-success">连接</button>
                    <button onclick="editSSHConfig('${config.id}')" class="btn btn-primary">编辑</button>
                    <button onclick="deleteSSHConfig('${config.id}')" class="btn btn-danger">删除</button>
                </div>
            </div>
        `).join('');
        
    } catch (error) {
        showToast(`加载配置失败: ${error.message}`, 'error');
    }
}

let editingSSHConfigId = null;

function showAddSSHModal() {
    editingSSHConfigId = null;
    document.getElementById('form-add-ssh').reset();
    document.querySelector('#modal-add-ssh h3').textContent = '添加 SSH 配置';
    showModal('modal-add-ssh');
}

async function editSSHConfig(configId) {
    try {
        const result = await apiCall(`/api/ssh/configs/${configId}`);
        const config = result.config;
        
        editingSSHConfigId = configId;
        
        // 填充表单（使用表单内部选择器）
        const form = document.getElementById('form-add-ssh');
        form.querySelector('[name="name"]').value = config.name;
        form.querySelector('[name="host"]').value = config.host;
        form.querySelector('[name="port"]').value = config.port;
        form.querySelector('[name="username"]').value = config.username;
        form.querySelector('[name="auth_type"]').value = config.auth_type;
        
        toggleAuthType(config.auth_type);
        
        if (config.auth_type === 'password') {
            form.querySelector('[name="password"]').value = config.password || '';
        } else {
            form.querySelector('[name="private_key"]').value = config.private_key || '';
        }
        
        document.querySelector('#modal-add-ssh h3').textContent = '编辑 SSH 配置';
        showModal('modal-add-ssh');
        
    } catch (error) {
        showToast(`加载配置失败: ${error.message}`, 'error');
    }
}

function toggleAuthType(authType) {
    const passwordDiv = document.getElementById('auth-password');
    const privateKeyDiv = document.getElementById('auth-private-key');
    
    if (authType === 'password') {
        passwordDiv.style.display = 'block';
        privateKeyDiv.style.display = 'none';
    } else {
        passwordDiv.style.display = 'none';
        privateKeyDiv.style.display = 'block';
    }
}

document.getElementById('form-add-ssh').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData);
    data.port = parseInt(data.port);
    
    try {
        if (editingSSHConfigId) {
            // 编辑模式
            await apiCall(`/api/ssh/configs/${editingSSHConfigId}`, 'PUT', data);
            showToast('配置已更新', 'success');
        } else {
            // 新增模式
            await apiCall('/api/ssh/configs', 'POST', data);
            showToast('配置已保存', 'success');
        }
        
        closeModal('modal-add-ssh');
        loadSSHConfigs();
        editingSSHConfigId = null;
    } catch (error) {
        showToast(`保存失败: ${error.message}`, 'error');
    }
});

async function connectSSHConfig(configId) {
    try {
        // 先获取配置信息（包含密码）
        const configResult = await apiCall(`/api/ssh/configs/${configId}`);
        const config = configResult.config;
        
        // 连接 SSH
        const result = await apiCall('/api/ssh/connect', 'POST', {
            config_id: configId
        });
        
        currentConnectionId = result.connection_id;
        const info = result.info;
        updateConnectionStatus(true, `${info.username}@${info.host}`);
        
        // 保存配置ID供重连使用
        lastConnectionConfigId = configId;
        currentSelectedConfigId = configId;
        
        // 如果使用密码认证，自动保存 sudo 密码
        if (config.auth_type === 'password' && config.password) {
            sudoPassword = config.password;
            showToast('连接成功！正在打开终端...', 'success');
        } else {
            showToast('连接成功！正在打开终端...', 'success');
        }
        
        await loadConnections();
        
        // 自动打开悬浮终端
        await openFloatingTerminal();
        
        // 设置下拉框为当前配置
        const floatingSelect = document.getElementById('floating-connection-select');
        if (floatingSelect) {
            floatingSelect.value = configId;
            
            // 添加已连接标记
            const selectedOption = floatingSelect.options[floatingSelect.selectedIndex];
            if (selectedOption && !selectedOption.text.startsWith('✓')) {
                selectedOption.text = '✓ ' + selectedOption.text;
            }
            
            // 建立终端WebSocket连接
            await connectExistingSSHToTerminal(currentConnectionId, configId);
        }
        
    } catch (error) {
        showToast(`连接失败: ${error.message}`, 'error');
    }
}

async function deleteSSHConfig(configId) {
    if (!confirm('确定要删除此配置吗？')) {
        return;
    }
    
    try {
        await apiCall(`/api/ssh/configs/${configId}`, 'DELETE');
        showToast('配置已删除', 'success');
        loadSSHConfigs();
    } catch (error) {
        showToast(`删除失败: ${error.message}`, 'error');
    }
}

async function setupDockerMirror() {
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('请先连接终端', 'error');
        return;
    }
    
    if (!confirm('🚀 配置 Docker 镜像加速器\n\n镜像源：docker.1ms.run\n\n此操作会重载 Docker 服务（不影响运行中的容器）\n\n是否继续？')) {
        return;
    }
    
    showToast('正在配置镜像加速器...', 'info');
    
    try {
        const result = await apiCall(`/api/ssh/setup-docker-mirror/${currentConnectionId}`, 'POST');
        
        // 打开悬浮终端显示结果
        if (!document.getElementById('floating-terminal').classList.contains('show')) {
            await openFloatingTerminal();
        }
        
        // 只在终端显示stdout（stderr的警告可以忽略）
        if (floatingTerminal && result.stdout) {
            floatingTerminal.write(result.stdout);
        }
        
        if (result.success) {
            showToast('✅ 镜像加速器配置成功！', 'success');
        } else {
            showToast('❌ 配置失败，请查看终端输出', 'error');
        }
        
    } catch (error) {
        showToast(`配置失败: ${error.message}`, 'error');
    }
}

async function restoreDockerConfig() {
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('请先连接终端', 'error');
        return;
    }
    
    if (!currentConnectionId) {
        showToast('请先连接一个 SSH 服务器', 'error');
        return;
    }
    
    if (!confirm('↩️ 恢复 Docker 原配置\n\n将删除镜像加速器配置\n\n⚠️ 注意：会重启 Docker 服务\n运行中的容器会短暂中断1-2秒\n\n是否继续？')) {
        return;
    }
    
    showToast('正在恢复原配置...', 'info');
    
    try {
        const result = await apiCall(`/api/ssh/restore-docker-config/${currentConnectionId}`, 'POST');
        
        if (floatingTerminal && result.stdout) {
            floatingTerminal.write(result.stdout);
        }
        
        if (result.success) {
            showToast('✅ 已恢复原配置！', 'success');
        } else {
            showToast('❌ 恢复失败', 'error');
        }
        
    } catch (error) {
        showToast(`恢复失败: ${error.message}`, 'error');
    }
}

// ===== 连接管理 =====

async function loadConnections() {
    try {
        const result = await apiCall('/api/ssh/connections');
        connections = result.connections;
        
        // 更新所有连接选择器
        const executeSelect = document.getElementById('execute-connection-select');
        
        const options = connections.map(conn => {
            const display = conn.name ? `${conn.name} (${conn.username}@${conn.host}:${conn.port})` : `${conn.username}@${conn.host}:${conn.port}`;
            return `<option value="${conn.connection_id}">${display}</option>`;
        }).join('');
        
        executeSelect.innerHTML = '<option value="">选择 SSH 连接</option>' + options;
        
        // 更新悬浮终端连接选择器
        updateFloatingConnectionSelect();
        
        // 如果有当前连接，设置为选中
        if (currentConnectionId) {
            executeSelect.value = currentConnectionId;
        }
        
    } catch (error) {
        console.error('加载连接失败:', error);
    }
}

// ===== 命令模板管理 =====

async function loadTemplates() {
    try {
        const result = await apiCall('/api/templates');
        const container = document.getElementById('templates-list');
        
        if (result.templates.length === 0) {
            container.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">暂无模板</p>';
            return;
        }
        
        container.innerHTML = result.templates.map(template => `
            <div class="template-card">
                <div class="template-header">
                    <div class="template-info">
                        <h3>${template.name}</h3>
                        <p>${template.description}</p>
                    </div>
                    <div class="template-actions">
                        <button onclick='executeTemplateModal(${JSON.stringify(template).replace(/'/g, "&apos;")})' class="btn btn-success">执行</button>
                        <button onclick="deleteTemplate('${template.id}')" class="btn btn-danger">删除</button>
                    </div>
                </div>
                <div class="template-command">${escapeHtml(template.command)}</div>
                ${template.variables && template.variables.length > 0 ? `
                    <div class="template-variables">
                        ${template.variables.map(v => `<span class="variable-tag">\${${v.name}}</span>`).join('')}
                    </div>
                ` : ''}
            </div>
        `).join('');
        
    } catch (error) {
        showToast(`加载模板失败: ${error.message}`, 'error');
    }
}

function showAddTemplateModal() {
    document.getElementById('form-add-template').reset();
    showModal('modal-add-template');
}

document.getElementById('form-add-template').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData);
    data.variables = [];
    
    try {
        await apiCall('/api/templates', 'POST', data);
        showToast('模板已创建', 'success');
        closeModal('modal-add-template');
        loadTemplates();
    } catch (error) {
        showToast(`创建失败: ${error.message}`, 'error');
    }
});

async function deleteTemplate(templateId) {
    if (!confirm('确定要删除此模板吗？')) {
        return;
    }
    
    try {
        await apiCall(`/api/templates/${templateId}`, 'DELETE');
        showToast('模板已删除', 'success');
        loadTemplates();
    } catch (error) {
        showToast(`删除失败: ${error.message}`, 'error');
    }
}

function executeTemplateModal(template) {
    currentTemplate = template;
    
    // 生成变量输入表单
    const form = document.getElementById('template-variables-form');
    form.innerHTML = '';
    
    if (template.variables && template.variables.length > 0) {
        template.variables.forEach(v => {
            form.innerHTML += `
                <div class="form-group">
                    <label>${v.description || v.name}</label>
                    <input type="text" 
                           class="input variable-input" 
                           data-var="${v.name}" 
                           value="${v.default || ''}"
                           placeholder="${v.description || v.name}">
                </div>
            `;
        });
        
        // 添加实时预览
        form.querySelectorAll('.variable-input').forEach(input => {
            input.addEventListener('input', updateCommandPreview);
        });
    }
    
    // 自动选中当前连接
    const executeSelect = document.getElementById('execute-connection-select');
    if (currentConnectionId && executeSelect) {
        executeSelect.value = currentConnectionId;
    }
    
    updateCommandPreview();
    
    // 修改执行按钮的 onclick 事件
    const executeButton = document.querySelector('#modal-execute-template .btn-success');
    if (currentDockerApp) {
        // 如果是 Docker 应用，使用 Docker 执行函数
        executeButton.setAttribute('onclick', 'executeDockerApp()');
    } else {
        // 如果是普通模板，使用模板执行函数
        executeButton.setAttribute('onclick', 'executeTemplate()');
    }
    
    showModal('modal-execute-template');
}

function updateCommandPreview() {
    if (!currentTemplate) return;
    
    let command;
    
    // 判断是脚本方式还是命令方式
    if (currentTemplate.script_content) {
        // 脚本方式，显示脚本路径和参数
        const inputs = document.querySelectorAll('.variable-input');
        const params = [];
        inputs.forEach(input => {
            const value = input.value || `\${${input.getAttribute('data-var')}}`;
            params.push(value);
        });
        command = `bash ${currentTemplate.script || 'script.sh'} ${params.join(' ')}`;
    } else if (currentTemplate.command) {
        // 命令方式，替换变量
        command = currentTemplate.command;
        const inputs = document.querySelectorAll('.variable-input');
        inputs.forEach(input => {
            const varName = input.getAttribute('data-var');
            const value = input.value || `\${${varName}}`;
            command = command.replace(new RegExp(`\\$\\{${varName}\\}`, 'g'), value);
        });
    } else {
        command = '(无命令)';
    }
    
    document.getElementById('command-preview').textContent = command;
}

async function executeTemplate() {
    const connectionId = document.getElementById('execute-connection-select').value;
    
    if (!connectionId) {
        showToast('请先选择 SSH 连接', 'error');
        return;
    }
    
    // 收集变量值
    const variables = {};
    document.querySelectorAll('.variable-input').forEach(input => {
        const varName = input.getAttribute('data-var');
        variables[varName] = input.value;
    });
    
    try {
        const result = await apiCall(
            `/api/templates/${currentTemplate.id}/execute?connection_id=${connectionId}`,
            'POST',
            variables
        );
        
        closeModal('modal-execute-template');
        showExecutionResult(result);
        
    } catch (error) {
        showToast(`执行失败: ${error.message}`, 'error');
    }
}

// ===== Docker 应用管理 =====

async function loadDockerApps(category = 'all') {
    try {
        const result = await apiCall('/api/docker/apps');
        const container = document.getElementById('docker-apps-grid');
        
        // 显示应用来源
        const sourceSpan = document.getElementById('apps-source');
        if (sourceSpan) {
            const sourceText = {
                'online': '🌐 在线',
                'cached': '📦 缓存',
                'builtin': '📁 内置'
            }[result.source] || '';
            sourceSpan.textContent = sourceText;
            sourceSpan.className = 'apps-source ' + result.source;
        }
        
        // 保存所有应用数据（供批量安装使用）
        allDockerApps = result.apps;
        
        let apps = result.apps;
        if (category !== 'all') {
            apps = apps.filter(app => app.category === category);
        }
        
        if (apps.length === 0) {
            container.innerHTML = '<p style="text-align: center; color: var(--text-secondary); grid-column: 1/-1;">暂无应用</p>';
            return;
        }
        
        container.innerHTML = apps.map(app => `
            <div class="docker-app-card ${selectedApps.find(a => a.id === app.id) ? 'selected' : ''}" data-app-id="${app.id}">
                ${isBatchMode ? `
                    <div class="app-checkbox">
                        <input type="checkbox" 
                               id="check-${app.id}" 
                               ${selectedApps.find(a => a.id === app.id) ? 'checked' : ''}
                               onchange="toggleAppSelection('${app.id}')">
                    </div>
                ` : ''}
                <div class="app-header">
                    <div class="app-icon">${app.icon}</div>
                    <div class="app-info">
                        <h3>${app.name}</h3>
                        <span class="app-category">${app.category}</span>
                    </div>
                </div>
                <p class="app-description">${app.description}</p>
                ${app.script ? `
                    <div class="app-command" title="脚本文件: ${app.script}">📄 ${app.script.split('/').pop()}</div>
                ` : app.command ? `
                    <div class="app-command">${escapeHtml(app.command)}</div>
                ` : ''}
                ${app.variables && app.variables.length > 0 ? `
                    <div class="app-variables">
                        ${app.variables.map(v => `<span class="variable-tag">\${${v.name}}</span>`).join('')}
                    </div>
                ` : ''}
                <div class="app-actions">
                    ${!isBatchMode ? `
                        <button onclick='installDockerApp(${JSON.stringify(app).replace(/'/g, "&apos;")})' class="btn btn-success">一键安装</button>
                    ` : ''}
                </div>
            </div>
        `).join('');
        
    } catch (error) {
        showToast(`加载应用失败: ${error.message}`, 'error');
    }
}

function showAddDockerAppModal() {
    showModal('modal-add-template'); // 重用模板模态框
}

function requestNewApp() {
    const issueUrl = 'https://github.com/kidoneself/dockssh/issues/new?title=【应用需求】&body=**应用名称：**%0A%0A**应用描述：**%0A%0A**Docker镜像：**%0A%0A**需要的参数：**%0A%0A**其他说明：**';
    window.open(issueUrl, '_blank');
    showToast('已打开GitHub Issue页面，请填写需求', 'success');
}

// ===== 批量安装功能 =====

let allDockerApps = []; // 保存所有应用数据

function toggleBatchMode() {
    isBatchMode = !isBatchMode;
    
    if (isBatchMode) {
        document.getElementById('batch-mode-btn').style.display = 'none';
        document.getElementById('batch-install-btn').style.display = 'inline-block';
        document.getElementById('cancel-batch-btn').style.display = 'inline-block';
        showToast('批量模式已开启，点击应用卡片选择', 'success');
    } else {
        selectedApps = [];
        document.getElementById('batch-mode-btn').style.display = 'inline-block';
        document.getElementById('batch-install-btn').style.display = 'none';
        document.getElementById('cancel-batch-btn').style.display = 'none';
    }
    
    loadDockerApps(document.querySelector('.filter-btn.active').dataset.category);
}

function cancelBatchMode() {
    isBatchMode = false;
    selectedApps = [];
    document.getElementById('batch-mode-btn').style.display = 'inline-block';
    document.getElementById('batch-install-btn').style.display = 'none';
    document.getElementById('cancel-batch-btn').style.display = 'none';
    loadDockerApps(document.querySelector('.filter-btn.active').dataset.category);
}

function toggleAppSelection(appId) {
    const app = allDockerApps.find(a => a.id === appId);
    if (!app) return;
    
    const index = selectedApps.findIndex(a => a.id === appId);
    if (index > -1) {
        selectedApps.splice(index, 1);
    } else {
        selectedApps.push(app);
    }
    
    // 更新选中计数
    document.getElementById('selected-count').textContent = selectedApps.length;
    
    // 更新卡片样式
    const card = document.querySelector(`[data-app-id="${appId}"]`);
    if (card) {
        if (selectedApps.find(a => a.id === appId)) {
            card.classList.add('selected');
        } else {
            card.classList.remove('selected');
        }
    }
}

function batchInstall() {
    if (selectedApps.length === 0) {
        showToast('请至少选择一个应用', 'error');
        return;
    }
    
    // 分析参数
    const { commonParams, uniqueParams } = analyzeParameters(selectedApps);
    
    // 生成批量安装表单
    generateBatchInstallForm(commonParams, uniqueParams);
    
    // 更新连接选择器
    const batchSelect = document.getElementById('batch-connection-select');
    const executeSelect = document.getElementById('execute-connection-select');
    batchSelect.innerHTML = executeSelect.innerHTML;
    if (currentConnectionId) {
        batchSelect.value = currentConnectionId;
    }
    
    showModal('modal-batch-install');
}

// 智能参数分析
function analyzeParameters(apps) {
    const paramCount = {};
    const paramInfo = {};
    
    // 统计每个参数出现的次数
    apps.forEach(app => {
        if (app.variables) {
            app.variables.forEach(variable => {
                const name = variable.name;
                if (!paramCount[name]) {
                    paramCount[name] = 0;
                    paramInfo[name] = variable;
                }
                paramCount[name]++;
            });
        }
    });
    
    // 分类参数
    const commonParams = [];
    const uniqueParams = {};
    
    for (const [name, count] of Object.entries(paramCount)) {
        if (count === apps.length) {
            // 所有应用都有 → 共同参数
            commonParams.push(paramInfo[name]);
        } else {
            // 只有部分应用有 → 记录到对应应用
            apps.forEach(app => {
                if (app.variables) {
                    const hasParam = app.variables.find(v => v.name === name);
                    if (hasParam) {
                        if (!uniqueParams[app.id]) {
                            uniqueParams[app.id] = [];
                        }
                        uniqueParams[app.id].push(hasParam);
                    }
                }
            });
        }
    }
    
    return { commonParams, uniqueParams };
}

// 生成批量安装表单
function generateBatchInstallForm(commonParams, uniqueParams) {
    const appsList = document.getElementById('batch-selected-apps');
    const varsForm = document.getElementById('batch-variables-form');
    
    // 显示选中的应用
    appsList.innerHTML = `
        <div class="batch-apps-summary">
            <h4>📦 已选择 ${selectedApps.length} 个应用</h4>
            <div class="apps-chips">
                ${selectedApps.map(app => `
                    <span class="app-chip">${app.icon} ${app.name}</span>
                `).join('')}
            </div>
        </div>
    `;
    
    // 生成参数输入表单
    let formHTML = '';
    
    // 共同参数区域
    if (commonParams.length > 0) {
        formHTML += `
            <div class="param-section common-params">
                <h4>📋 共同参数 (${selectedApps.length}个应用都需要)</h4>
                ${commonParams.map(param => `
                    <div class="form-group">
                        <label>${param.description}</label>
                        <input type="text" 
                               class="input batch-common-param" 
                               data-name="${param.name}" 
                               value="${param.default || ''}"
                               placeholder="${param.description}">
                    </div>
                `).join('')}
            </div>
        `;
    }
    
    // 各应用独有参数
    for (const [appId, params] of Object.entries(uniqueParams)) {
        const app = selectedApps.find(a => a.id === appId);
        if (params.length > 0 && app) {
            formHTML += `
                <div class="param-section unique-params">
                    <h4>⚙️ ${app.icon} ${app.name} 专属参数</h4>
                    ${params.map(param => `
                        <div class="form-group">
                            <label>${param.description}</label>
                            <input type="text" 
                                   class="input batch-unique-param" 
                                   data-app="${appId}"
                                   data-name="${param.name}" 
                                   value="${param.default || ''}"
                                   placeholder="${param.description}">
                        </div>
                    `).join('')}
                </div>
            `;
        }
    }
    
    varsForm.innerHTML = formHTML;
}

// 执行批量安装
async function executeBatchInstall() {
    const connectionId = document.getElementById('batch-connection-select').value;
    
    if (!connectionId) {
        showToast('请先选择 SSH 连接', 'error');
        return;
    }
    
    // 收集共同参数
    const commonValues = {};
    document.querySelectorAll('.batch-common-param').forEach(input => {
        commonValues[input.dataset.name] = input.value;
    });
    
    // 关闭对话框
    closeModal('modal-batch-install');
    
    // 打开悬浮终端
    if (!document.getElementById('floating-terminal').classList.contains('show')) {
        await openFloatingTerminal();
    }
    
    // 确保终端已连接
    const floatingSelect = document.getElementById('floating-connection-select');
    floatingSelect.value = currentSelectedConfigId;
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        await autoConnectTerminal();
        await new Promise(resolve => setTimeout(resolve, 1500));
    }
    
    // 生成批量安装脚本（所有命令合并）
    const batchCommands = [];
    
    for (let i = 0; i < selectedApps.length; i++) {
        const app = selectedApps[i];
        
        // 组装该应用的完整参数
        const appParams = {...commonValues};
        
        // 添加该应用的独有参数
        document.querySelectorAll(`.batch-unique-param[data-app="${app.id}"]`).forEach(input => {
            appParams[input.dataset.name] = input.value;
        });
        
        // 按照variables顺序构建参数数组
        const varValues = app.variables ? app.variables.map(v => appParams[v.name] || v.default || '') : [];
        
        // 生成命令
        if (app.script_content) {
            // 直接添加脚本执行命令
            batchCommands.push(`
echo ""
echo "========================================"
echo "📦 [${i + 1}/${selectedApps.length}] 正在安装 ${app.name}..."
echo "========================================"
cat > /tmp/install_${app.id}.sh << 'BATCH_EOF'
${app.script_content}
BATCH_EOF
chmod +x /tmp/install_${app.id}.sh
sudo bash /tmp/install_${app.id}.sh ${varValues.join(' ')}
rm -f /tmp/install_${app.id}.sh
`);
        }
    }
    
    // 合并所有命令为一个大脚本（不使用 set -e，失败也继续）
    const finalScript = `/tmp/batch_install_${Date.now()}.sh`;
    const allCommands = `cat > ${finalScript} << 'FINAL_EOF'
#!/bin/bash

# 定义 docker 函数来劫持 docker pull 命令（自动使用加速源）
docker() {
    if [ "$1" = "pull" ]; then
        local image="$2"
        echo "   🚀 使用加速源: $image"
        if command docker pull docker.1ms.run/$image 2>/dev/null; then
            command docker tag docker.1ms.run/$image $image
            command docker rmi docker.1ms.run/$image 2>/dev/null || true
        else
            echo "   加速源失败，使用官方源..."
            command docker pull $image
        fi
    else
        command docker "$@"
    fi
}
export -f docker

SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_APPS=""

echo ""
echo "========================================="
echo "🚀 开始批量安装 ${selectedApps.length} 个应用"
echo "========================================="

${selectedApps.map((app, i) => {
    const appParams = {...commonValues};
    document.querySelectorAll(`.batch-unique-param[data-app="${app.id}"]`).forEach(input => {
        appParams[input.dataset.name] = input.value;
    });
    const varValues = app.variables ? app.variables.map(v => appParams[v.name] || v.default || '') : [];
    
    return `
# 安装 ${app.name}
echo ""
echo "📦 [${i + 1}/${selectedApps.length}] 正在安装 ${app.name}..."
if cat > /tmp/install_${app.id}.sh << 'APP_EOF'
${app.script_content || ''}
APP_EOF
then
    chmod +x /tmp/install_${app.id}.sh
    if sudo bash /tmp/install_${app.id}.sh ${varValues.join(' ')}; then
        SUCCESS_COUNT=\$((SUCCESS_COUNT + 1))
        echo "   ✅ ${app.name} 安装成功"
    else
        FAILED_COUNT=\$((FAILED_COUNT + 1))
        FAILED_APPS="\$FAILED_APPS ${app.name}"
        echo "   ❌ ${app.name} 安装失败（继续安装下一个）"
    fi
    rm -f /tmp/install_${app.id}.sh
fi
`;
}).join('\n')}

echo ""
echo "========================================="
echo "📊 批量安装完成！"
echo "========================================="
echo "✅ 成功: \$SUCCESS_COUNT 个"
echo "❌ 失败: \$FAILED_COUNT 个"
if [ \$FAILED_COUNT -gt 0 ]; then
    echo "失败的应用:\$FAILED_APPS"
fi
echo "========================================="
FINAL_EOF
chmod +x ${finalScript}
sudo bash ${finalScript}
rm -f ${finalScript}`;
    
    // 发送到终端
    if (terminalSocket && terminalSocket.readyState === WebSocket.OPEN) {
        terminalSocket.send(allCommands + '\n');
        showToast(`🚀 开始批量安装 ${selectedApps.length} 个应用...`, 'success');
    }
    
    // 退出批量模式
    cancelBatchMode();
}

function installDockerApp(app) {
    console.log('安装 Docker 应用:', app);
    currentDockerApp = app;
    currentTemplate = app; // 重用模板执行逻辑
    
    // 清空之前的 command 字段（避免旧数据干扰）
    if (!app.command && !app.script_content) {
        console.error('应用配置错误：缺少 command 或 script_content');
    }
    
    executeTemplateModal(app);
}

// 执行 Docker 应用安装（跳转到终端执行）
async function executeDockerApp() {
    const connectionId = document.getElementById('execute-connection-select').value;
    
    if (!connectionId) {
        showToast('请先选择 SSH 连接', 'error');
        return;
    }
    
    // 收集变量值
    const variables = {};
    const varValues = [];
    document.querySelectorAll('.variable-input').forEach(input => {
        const varName = input.getAttribute('data-var');
        const value = input.value;
        variables[varName] = value;
        varValues.push(value);
    });
    
    // 生成命令
    let command;
    if (currentDockerApp.script_content) {
        // 使用脚本内容方式 - 直接上传到远程服务器执行
        const scriptName = `/tmp/dockssh_${currentDockerApp.id}_${Date.now()}.sh`;
        const scriptContent = currentDockerApp.script_content;
        
        // 生成上传并执行的命令（包含 docker pull 劫持）
        command = `cat > ${scriptName} << 'DOCKSSH_EOF'
${scriptContent}
DOCKSSH_EOF
chmod +x ${scriptName}
cat > /tmp/docker_wrapper.sh << 'WRAPPER_EOF'
#!/bin/bash
docker() {
    if [ "$1" = "pull" ]; then
        local image="$2"
        echo ""
        echo "   🚀 镜像加速拉取: $image"
        echo "   → 尝试加速源: docker.1ms.run/$image"
        if command docker pull docker.1ms.run/$image 2>&1 | grep -E "(Pulling|Download|already exists|Status)"; then
            command docker tag docker.1ms.run/$image $image 2>/dev/null
            command docker rmi docker.1ms.run/$image 2>/dev/null || true
            echo "   ✓ 加速源下载成功，已标记为 $image"
        else
            echo "   ⚠️ 加速源失败，使用官方源..."
            command docker pull $image
        fi
        echo ""
    else
        command docker "$@"
    fi
}
export -f docker
source ${scriptName} ${varValues.join(' ')}
WRAPPER_EOF
chmod +x /tmp/docker_wrapper.sh
sudo bash /tmp/docker_wrapper.sh
rm -f ${scriptName} /tmp/docker_wrapper.sh`;
    } else if (currentDockerApp.command) {
        // 使用旧的 command 方式（向后兼容）
        command = currentDockerApp.command;
        for (const [key, value] of Object.entries(variables)) {
            command = command.replace(new RegExp(`\\$\\{${key}\\}`, 'g'), value);
        }
    } else {
        showToast('应用配置错误', 'error');
        return;
    }
    
    // 关闭模态框
    closeModal('modal-execute-template');
    
    // 打开悬浮终端
    if (!document.getElementById('floating-terminal').classList.contains('show')) {
        openFloatingTerminal();
    }
    
    // 等待终端初始化
    setTimeout(async () => {
        // 设置连接
        document.getElementById('floating-connection-select').value = connectionId;
        
        // 如果终端未连接，先连接
        if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
            await autoConnectTerminal();
            
            // 等待终端连接成功后直接执行整个命令
            setTimeout(() => {
                if (terminalSocket && terminalSocket.readyState === WebSocket.OPEN) {
                    // 直接发送整个命令，不要逐行执行
                    terminalSocket.send(command + '\n');
                    showToast('正在安装，请查看终端输出...', 'success');
                }
            }, 1000);
        } else {
            // 终端已连接，直接发送整个命令
            terminalSocket.send(command + '\n');
            showToast('正在安装，请查看终端输出...', 'success');
        }
    }, 500);
}

// 在终端中逐行执行命令（支持多行脚本）
function executeCommandsInTerminal(commandText) {
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('终端未连接', 'error');
        return;
    }
    
    // 按行拆分命令
    const lines = commandText.split('\n').map(line => line.trim()).filter(line => {
        // 过滤掉空行和注释行
        return line && !line.startsWith('#');
    });
    
    if (lines.length === 0) {
        showToast('没有可执行的命令', 'warning');
        return;
    }
    
    if (lines.length === 1) {
        // 单行命令，直接执行
        terminalSocket.send(lines[0] + '\n');
        showToast('命令已发送 🚀', 'success');
    } else {
        // 多行命令，逐行执行
        showToast(`正在执行 ${lines.length} 条命令...`, 'success');
        executeCommandSequence(lines, 0);
    }
}

// 顺序执行命令序列
function executeCommandSequence(commands, index) {
    if (index >= commands.length) {
        showToast('✅ 所有命令执行完成', 'success');
        return;
    }
    
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('终端连接已断开', 'error');
        return;
    }
    
    const command = commands[index];
    
    // 在终端显示当前执行的是第几条命令
    const currentTerminal = floatingTerminal || terminal;
    if (index === 0 && currentTerminal) {
        currentTerminal.writeln(`\r\n\x1b[36m=== 开始执行安装脚本 (${commands.length} 条命令) ===\x1b[0m\r\n`);
    }
    
    if (currentTerminal) {
        currentTerminal.writeln(`\x1b[33m[${index + 1}/${commands.length}]\x1b[0m ${command}`);
    }
    
    // 发送命令
    terminalSocket.send(command + '\n');
    
    // 等待一段时间后执行下一条（给命令执行留时间）
    // 对于耗时操作（如 docker pull），可能需要更长时间
    let delay = 2000; // 默认 2 秒
    
    // 根据命令类型调整延迟
    if (command.includes('docker pull') || command.includes('docker build')) {
        delay = 5000; // pull/build 需要更长时间
    } else if (command.includes('apt') || command.includes('yum')) {
        delay = 3000; // 包管理命令需要更多时间
    } else if (command.includes('mkdir') || command.includes('chmod') || command.includes('cd')) {
        delay = 500; // 文件系统操作很快
    }
    
    setTimeout(() => {
        executeCommandSequence(commands, index + 1);
    }, delay);
}

// ===== 终端管理 =====

function initTerminal() {
    if (terminal) return;
    
    const container = document.getElementById('terminal-container');
    terminal = new Terminal({
        cursorBlink: true,
        fontSize: 14,
        fontFamily: 'Monaco, Menlo, Consolas, monospace',
        theme: {
            background: '#1e1e1e',
            foreground: '#f0f0f0',
        }
    });
    
    const fitAddon = new FitAddon.FitAddon();
    terminal.loadAddon(fitAddon);
    
    terminal.open(container);
    fitAddon.fit();
    
    // 窗口大小变化时重新适应
    window.addEventListener('resize', () => {
        if (terminal) {
            fitAddon.fit();
        }
    });
    
    terminal.writeln('欢迎使用 DockSSH 终端');
    terminal.writeln('请选择连接后点击"连接终端"按钮');
    terminal.writeln('');
}

async function connectTerminal() {
    const connectionId = document.getElementById('terminal-connection-select').value;
    
    if (!connectionId) {
        showToast('请先选择 SSH 连接', 'error');
        return;
    }
    
    if (!terminal) {
        initTerminal();
    }
    
    // 自动从配置中加载 sudo 密码
    if (!sudoPassword) {
        await loadSudoPasswordFromConfigs();
    }
    
    // 关闭旧连接
    if (terminalSocket) {
        terminalSocket.close();
    }
    
    // 建立 WebSocket 连接
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/terminal/${connectionId}`;
    
    terminalSocket = new WebSocket(wsUrl);
    
    terminalSocket.onopen = () => {
        showToast('终端已连接', 'success');
    };
    
    terminalSocket.onmessage = (event) => {
        const message = JSON.parse(event.data);
        
        if (message.type === 'output' || message.type === 'connected') {
            terminal.write(message.data);
        } else if (message.type === 'error') {
            terminal.writeln(`\r\n错误: ${message.data}\r\n`);
        }
    };
    
    terminalSocket.onerror = (error) => {
        showToast('终端连接错误', 'error');
        console.error('WebSocket 错误:', error);
    };
    
    terminalSocket.onclose = () => {
        terminal.writeln('\r\n\r\n终端连接已断开\r\n');
        showToast('终端已断开', 'warning');
    };
    
    // 监听终端输入
    terminal.onData((data) => {
        if (terminalSocket && terminalSocket.readyState === WebSocket.OPEN) {
            terminalSocket.send(data);
        }
    });
}

function disconnectTerminal() {
    if (terminalSocket) {
        terminalSocket.close();
        terminalSocket = null;
        showToast('已断开终端连接', 'success');
    }
}

function sendTerminalCommand(command) {
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('请先连接终端', 'error');
        return;
    }
    
    // 发送命令（自动添加回车）
    terminalSocket.send(command + '\n');
    showToast(`执行命令: ${command}`, 'success');
}

function sendCtrlC() {
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('请先连接终端', 'error');
        return;
    }
    
    // 发送 Ctrl+C 信号 (ASCII 码 3)
    terminalSocket.send('\x03');
    showToast('已发送 Ctrl+C', 'warning');
}

async function switchToRoot() {
    if (!terminalSocket || terminalSocket.readyState !== WebSocket.OPEN) {
        showToast('请先连接终端', 'error');
        return;
    }
    
    // 如果没有密码，尝试从配置中加载
    if (!sudoPassword) {
        await loadSudoPasswordFromConfigs();
    }
    
    // 如果还是没有密码，直接发送命令让用户手动输入
    if (!sudoPassword) {
        terminalSocket.send('sudo -i\n');
        showToast('未找到密码配置，请手动输入', 'warning');
        return;
    }
    
    // 最简单的方式：发送命令，然后自动输入密码
    terminalSocket.send('sudo -i\n');
    
    // 等待 500ms 后自动发送密码
    setTimeout(() => {
        terminalSocket.send(sudoPassword + '\n');
        showToast('已切换到 root 🎉', 'success');
    }, 500);
}

async function loadSudoPasswordFromConfigs() {
    try {
        // 获取所有 SSH 配置
        const result = await apiCall('/api/ssh/configs');
        const configs = result.configs;
        
        // 查找第一个有密码的配置
        for (const config of configs) {
            // 需要获取完整配置（包括密码）
            const fullConfig = await apiCall(`/api/ssh/configs/${config.id}`);
            if (fullConfig.config.auth_type === 'password' && fullConfig.config.password) {
                sudoPassword = fullConfig.config.password;
                console.log('已从配置中自动加载 sudo 密码');
                return;
            }
        }
    } catch (error) {
        console.error('加载配置密码失败:', error);
    }
}

function showSudoPasswordModal() {
    document.getElementById('sudo-password-input').value = sudoPassword;
    showModal('modal-sudo-password');
}

function saveSudoPassword() {
    const password = document.getElementById('sudo-password-input').value;
    if (password) {
        sudoPassword = password;
        closeModal('modal-sudo-password');
        showToast('sudo 密码已保存（仅存储在内存中）', 'success');
    } else {
        showToast('请输入密码', 'error');
    }
}

// ===== 执行结果显示 =====

function showExecutionResult(result) {
    const content = document.getElementById('execution-result-content');
    
    const isSuccess = result.success || result.exit_code === 0;
    const statusClass = isSuccess ? 'success' : 'error';
    const statusText = isSuccess ? '成功' : '失败';
    const statusIcon = isSuccess ? '✅' : '❌';
    
    content.innerHTML = `
        <div class="result-section">
            <h4>${statusIcon} 执行状态: ${statusText} (退出码: ${result.exit_code})</h4>
        </div>
        
        <div class="result-section">
            <h4>📝 执行命令:</h4>
            <div class="command-preview">${escapeHtml(result.command)}</div>
        </div>
        
        ${result.stdout ? `
            <div class="result-section">
                <h4>📤 标准输出:</h4>
                <div class="result-output ${statusClass}">${escapeHtml(result.stdout)}</div>
            </div>
        ` : ''}
        
        ${result.stderr ? `
            <div class="result-section">
                <h4>⚠️ 错误输出:</h4>
                <div class="result-output error">${escapeHtml(result.stderr)}</div>
            </div>
        ` : ''}
    `;
    
    showModal('modal-execution-result');
    
    if (isSuccess) {
        showToast('命令执行成功', 'success');
    } else {
        showToast('命令执行失败', 'error');
    }
}

// ===== 工具函数 =====

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function getLocalIP() {
    // 从当前连接获取本机IP
    // 如果从 10.10.10.X 访问，说明本机IP在同一网段
    const conn = connections.find(c => c.connection_id === currentConnectionId);
    if (conn && conn.host) {
        // 简单猜测：如果远程是 10.10.10.17，本机可能是 10.10.10.X
        // 用户需要在这里配置自己电脑的IP
        // 临时方案：提示用户
        const userIP = prompt('请输入你电脑的局域网IP地址\n（远程服务器需要能访问到这个IP）\n例如: 10.10.10.2', '10.10.10.2');
        return userIP || 'localhost';
    }
    return 'localhost';
}

// ===== 悬浮终端管理 =====

let floatingTerminal = null;
let floatingFitAddon = null;
let isTerminalMaximized = false;

function toggleFloatingTerminal() {
    const terminalDiv = document.getElementById('floating-terminal');
    const btn = document.getElementById('floating-terminal-btn');
    
    if (terminalDiv.classList.contains('show')) {
        closeFloatingTerminal();
    } else {
        openFloatingTerminal();
    }
}

async function openFloatingTerminal() {
    const terminalDiv = document.getElementById('floating-terminal');
    terminalDiv.classList.add('show');
    
    // 初始化悬浮终端
    if (!floatingTerminal) {
        initFloatingTerminal();
    }
    
    // 等待连接列表更新完成
    await updateFloatingConnectionSelect();
}

function closeFloatingTerminal() {
    const terminalDiv = document.getElementById('floating-terminal');
    terminalDiv.classList.remove('show');
}

function minimizeTerminal() {
    const terminalDiv = document.getElementById('floating-terminal');
    terminalDiv.classList.toggle('minimized');
}

function maximizeTerminal() {
    const terminalDiv = document.getElementById('floating-terminal');
    terminalDiv.classList.toggle('maximized');
    isTerminalMaximized = !isTerminalMaximized;
    
    // 重新调整终端大小
    setTimeout(() => {
        if (floatingFitAddon) {
            floatingFitAddon.fit();
        }
    }, 100);
}

function initFloatingTerminal() {
    const container = document.getElementById('floating-terminal-container');
    
    floatingTerminal = new Terminal({
        cursorBlink: true,
        fontSize: 13,
        fontFamily: 'Monaco, Menlo, Consolas, monospace',
        theme: {
            background: '#1e1e1e',
            foreground: '#f0f0f0',
        }
    });
    
    floatingFitAddon = new FitAddon.FitAddon();
    floatingTerminal.loadAddon(floatingFitAddon);
    
    floatingTerminal.open(container);
    floatingFitAddon.fit();
    
    floatingTerminal.writeln('💻 DockSSH 悬浮终端');
    floatingTerminal.writeln('📌 在标题栏选择连接即可自动连接');
    floatingTerminal.writeln('');
    
    // 监听终端输入
    floatingTerminal.onData((data) => {
        if (terminalSocket && terminalSocket.readyState === WebSocket.OPEN) {
            terminalSocket.send(data);
        }
    });
    
    // 窗口大小变化时重新适应
    const resizeObserver = new ResizeObserver(() => {
        if (floatingFitAddon) {
            floatingFitAddon.fit();
        }
    });
    resizeObserver.observe(container);
    
    // 使终端头部可拖动
    makeDraggable();
}

let currentSelectedConfigId = null;

async function updateFloatingConnectionSelect() {
    const select = document.getElementById('floating-connection-select');
    
    // 记住当前选中的值
    const currentValue = select.value || currentSelectedConfigId;
    
    try {
        // 获取所有SSH配置（而不是活动连接）
        const result = await apiCall('/api/ssh/configs');
        const configs = result.configs;
        
        const options = configs.map(config => {
            return `<option value="${config.id}">${config.name} (${config.username}@${config.host}:${config.port})</option>`;
        }).join('');
        
        select.innerHTML = '<option value="">选择 SSH 配置</option>' + options;
        
        // 恢复之前选中的值
        if (currentValue) {
            select.value = currentValue;
        }
        
    } catch (error) {
        console.error('加载SSH配置失败:', error);
    }
}

async function autoConnectTerminal() {
    const configId = document.getElementById('floating-connection-select').value;
    
    if (!configId) {
        return;
    }
    
    // 保存选中的配置ID
    currentSelectedConfigId = configId;
    
    try {
        // 先建立SSH连接
        showToast('正在连接...', 'info');
        
        const result = await apiCall('/api/ssh/connect', 'POST', {
            config_id: configId
        });
        
        currentConnectionId = result.connection_id;
        const info = result.info;
        updateConnectionStatus(true, `${info.username}@${info.host}`);
        
        // 加载sudo密码
        const configResult = await apiCall(`/api/ssh/configs/${configId}`);
        const config = configResult.config;
        if (config.auth_type === 'password' && config.password) {
            sudoPassword = config.password;
        }
        
        await loadConnections();
        
        // 建立终端连接
        await connectExistingSSHToTerminal(currentConnectionId, configId);
        
    } catch (error) {
        showToast(`连接失败: ${error.message}`, 'error');
    }
}

// 连接已有的SSH到终端
async function connectExistingSSHToTerminal(connectionId, configId = null) {
    // 关闭旧的终端WebSocket
    if (terminalSocket) {
        terminalSocket.close();
    }
    
    // 建立 WebSocket 连接
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/terminal/${connectionId}`;
    
    terminalSocket = new WebSocket(wsUrl);
    terminal = floatingTerminal; // 使用悬浮终端
    
    terminalSocket.onopen = () => {
        showToast('终端已连接 ✓', 'success');
        
        // 连接成功后，添加勾选标记
        const select = document.getElementById('floating-connection-select');
        if (configId) {
            select.value = configId; // 确保选中
        }
        const selectedOption = select.options[select.selectedIndex];
        if (selectedOption && !selectedOption.text.startsWith('✓')) {
            selectedOption.text = '✓ ' + selectedOption.text;
        }
    };
    
    terminalSocket.onmessage = (event) => {
        const message = JSON.parse(event.data);
        
        if (message.type === 'output' || message.type === 'connected') {
            floatingTerminal.write(message.data);
        } else if (message.type === 'error') {
            floatingTerminal.writeln(`\r\n错误: ${message.data}\r\n`);
        }
    };
    
    terminalSocket.onerror = (error) => {
        showToast('终端连接错误', 'error');
    };
    
    terminalSocket.onclose = () => {
        floatingTerminal.writeln('\r\n\r\n终端连接已断开\r\n');
        showToast('终端已断开', 'warning');
        
        // 断开后移除勾选标记，但保持选中
        const select = document.getElementById('floating-connection-select');
        const selectedOption = select.options[select.selectedIndex];
        if (selectedOption) {
            selectedOption.text = selectedOption.text.replace('✓ ', '');
        }
    };
}

function makeDraggable() {
    const terminalDiv = document.getElementById('floating-terminal');
    const header = document.querySelector('.floating-terminal-header');
    
    let isDragging = false;
    let currentX, currentY, initialX, initialY;
    
    header.addEventListener('mousedown', (e) => {
        if (isTerminalMaximized) return;
        if (e.target.tagName === 'SELECT' || e.target.tagName === 'BUTTON') return;
        
        isDragging = true;
        initialX = e.clientX - terminalDiv.offsetLeft;
        initialY = e.clientY - terminalDiv.offsetTop;
    });
    
    document.addEventListener('mousemove', (e) => {
        if (!isDragging) return;
        
        e.preventDefault();
        currentX = e.clientX - initialX;
        currentY = e.clientY - initialY;
        
        terminalDiv.style.right = 'auto';
        terminalDiv.style.bottom = 'auto';
        terminalDiv.style.left = `${currentX}px`;
        terminalDiv.style.top = `${currentY}px`;
    });
    
    document.addEventListener('mouseup', () => {
        isDragging = false;
    });
}

// ===== 初始化 =====

document.addEventListener('DOMContentLoaded', () => {
    // 导航菜单点击事件
    document.querySelectorAll('.nav-menu a').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const page = link.getAttribute('data-page');
            showPage(page);
        });
    });
    
    // 分类筛选
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            const category = btn.getAttribute('data-category');
            loadDockerApps(category);
        });
    });
    
    // 模态框点击外部关闭
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });
    
    // 加载初始数据
    loadConnections();
    
    console.log('DockSSH 前端已加载');
});

