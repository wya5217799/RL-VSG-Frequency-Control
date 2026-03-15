# VSG 强化学习控制 - 代码变更日志

> 每次 Claude 对代码进行修改后，变更内容会记录在此文件中。
> 格式：`[日期] 变更标题`，附详细说明与受影响文件列表。

---

## [历史记录 - 从聊天记录还原]

### 阶段 1：DDPG 基础框架搭建
**时间**：研究初期
**目标**：建立 VSG 强化学习控制的基本框架
**主要变更**：
- 创建 `setup_vsg_rl.m`：初始化 MATLAB RL 工具箱环境，定义观测空间（频率偏差 Δω、有功功率 P、无功功率 Q）和动作空间（虚拟惯量 J、阻尼 D）
- 创建 `vsg_reset.m`：仿真环境重置函数，设置 Simulink 初始条件
- 创建 `vsg_step.m`：单步仿真推进，返回 (obs, reward, isDone) 元组
- 奖励函数设计：基于频率偏差和功率误差的加权惩罚

---

### 阶段 2：TD3 算法替换 & Ψ 自适应机制
**时间**：中期
**目标**：解决 DDPG 训练不稳定问题，引入 TD3 + Ψ 自适应惩罚系数
**主要变更**：
- 创建 `START_TRAINING_TD3.m`：TD3 智能体配置，双 Critic 网络，延迟策略更新
- 创建 `vsg_reset_td3.m` / `vsg_step_td3.m`：适配 TD3 的环境接口
- 创建 `RESUME_TD3.m`：支持从检查点恢复训练
- 引入 Ψ 自适应参数：动态调整奖励权重，阶段 2 达到 Average = -6.90
- 创建 `START_TRAINING.m` / `CONTINUE_TRAINING.m`：训练启动与断点续训脚本

---

### 阶段 3：v2 版本优化
**时间**：中后期
**目标**：改进观测空间和奖励塑形
**主要变更**：
- 创建 `vsg_reset_v2.m` / `vsg_step_v2.m`：扩展观测向量（新增 dω/dt 微分项），改进终止条件判断
- 优化 Simulink 模型 `Three_Phase_VSG_Double_Loop_Control.mdl`：调整电压/频率双环控制参数

---

### 阶段 4：基线对比与验证
**时间**：后期
**目标**：与传统 PI 控制器对比，验证 RL 方案有效性
**主要变更**：
- 创建 `baseline_comparison.m`：传统 PI 控制器基线测试脚本
- 创建 `final_validation.m`：最终验证脚本，对比 DDPG/TD3/PI 三种方案
- 生成对比图：`fig1_freq.png`（频率响应）、`fig2_metrics.png`（性能指标）、`fig_final_comparison.png`

---

## [正式版本管理 - 2026年3月15日起]

### 2026-03-14 | 初始 Git 提交
**Commit**: `145cb0f`
**内容**：TD3+Ψ 自适应VSG控制框架，阶段2达到 Average=-6.90
**文件**：`RESUME_TD3.m`, `START_TRAINING_TD3.m`, `final_validation.m`, `vsg_reset_td3.m`, `vsg_step_td3.m`

---

### 2026-03-15 | 版本管理系统建立
**Commit**: `5b637bf`
**内容**：补全所有源文件跟踪，配置 MATLAB 专用 `.gitignore`
**新增跟踪**：全部 `.m` 源文件、Simulink 模型、研究文档
**排除跟踪**：`saved_agents/`（训练权重）、`*.mat`（训练数据）、`slprj/`（编译缓存）

---

<!-- 以下由 Claude 在每次代码修改后自动追加 -->
