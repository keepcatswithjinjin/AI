# 后端测试与 Maven 构建规范

> 本文件定义多模块后端项目在当前 worktree 中的验证入口、Maven reactor 用法与测试证据标准。

## 一、适用范围

以下重要或复杂改动，执行完成前必须新增或更新对应的测试类，并执行定向 Maven 测试：

- 跨 Maven 模块调用链、公共 DTO / 枚举、配置或依赖调整；
- 外部接口、回调、MQ、定时任务、缓存、数据源、事务或权限变更；
- 金额、结算、统计口径、状态流转、支付、签约等关键业务逻辑；
- 新增接口、核心业务分支，或修复可稳定复现的后端缺陷。

简单且不改变业务行为的文案、样式、注释或纯局部机械改动，可说明理由后不新增测试类。

## 二、测试类要求

1. 在**实际包含被测代码的 Maven 模块**下 `src/test/java` 新增或更新 `*Test`。
2. 测试必须覆盖本次改动的主要调用链或故障复现路径；需要外部系统时使用项目现有测试方式、替身或 Mock，不能以真实生产调用替代测试。
3. 不得只新增空测试、仅断言非空，或只为让构建通过而关闭核心断言。
4. 若受环境、遗留架构或外部依赖限制无法完成有效测试，必须明确说明未覆盖边界和替代验证；不得宣称测试通过。

## 三、Maven reactor 定向测试

### 执行位置

命令必须从**当前需求 worktree 的 Maven 聚合根**执行：即根 `pom.xml` 中包含完整 `<modules>` 列表的目录。

- 禁止在目标子模块目录直接执行定向测试。
- 禁止为测试切回主仓库、切换分支，或依赖其他 worktree 的 `target/` 产物。
- 当前 worktree 源码是验证对象。

### 标准命令

```powershell
# 在当前 worktree 的 Maven 聚合根执行
mvn -s <项目settings文件> `
  -pl <相对聚合根的目标模块路径或artifactId> `
  -am `
  -Dtest=<目标测试类> `
  '-Dsurefire.failIfNoSpecifiedTests=false' `
  test
```

- `-pl`：选择实际包含目标测试类的模块。
- `-am`：把该模块所依赖的同仓上游模块纳入本次 reactor；不得省略。
- 项目提供 Maven settings 文件时必须通过 `-s` 显式指定；文件名以项目实际为准。
- 测试多个模块时，可分别执行定向命令；不要用本地 `install` 缓存代替当前 worktree 的 reactor 构建。

### 示例

```powershell
# 示例：当前需求 worktree 的 Maven 聚合根
mvn -s setting.xml `
  -pl service/order-module `
  -am `
  -Dtest=OrderServiceTest `
  '-Dsurefire.failIfNoSpecifiedTests=false' `
  test
```

## 四、首次与全量构建

首次进入新 worktree、POM/依赖发生较大变化，或需要确认完整编译边界时，可在当前 worktree 聚合根执行一次：

```powershell
mvn -s <项目settings文件> clean install -DskipTests
```

该操作用于准备第三方依赖和同仓模块产物，不替代本次改动的定向测试。日常开发优先使用 `-pl + -am + -Dtest`，避免无意义全量构建。

## 五、通过与失败证据

只有同时满足以下条件，才可报告“测试通过”：

1. Maven 进程退出码为 `0`；
2. 输出包含目标模块的 Reactor Summary 和 `BUILD SUCCESS`；
3. 目标模块 `target/surefire-reports/` 中存在目标测试对应的 `TEST-*.xml` 或报告文件；
4. 报告显示目标测试已执行且无失败/错误。

若依赖解析、编译、Surefire、上下文启动或断言任一环节失败，必须报告实际阶段与第一条有效错误；未生成 `surefire-reports` 代表测试尚未启动，不得描述为“测试失败”或“测试通过”。
