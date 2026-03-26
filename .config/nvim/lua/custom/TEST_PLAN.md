# Plan de tests — módulos custom

Cada test tiene:

- **Condición previa**: qué archivo abrir, dónde poner el cursor, estado del disco
- **Comando**: qué ejecutar en Neovim
- **Resultado esperado**: qué debe aparecer
- **Resultado real**: (completar al testear)

---

## Módulo 1: `test_context.lua`

Instalación: copiar a `~/.config/nvim/lua/custom/test_context.lua`

---

### CT-01 — JUnit 4 clase completa

**Condición previa**

- Abrir `GameTest.java`
- Cursor en cualquier línea DENTRO de la clase (no en un método específico)

**Comando**

```vim
:lua print(vim.inspect(require("custom.test_context").parse()))
```

**Resultado esperado**

```lua
{
  framework = "junit4",
  root_class = "GameTest",
  runner = "MockitoJUnitRunner",
  is_spring = false,
  is_disabled = false,
  method = nil,         -- o el método si el cursor está sobre uno
  nested_chain = {},
  parent_class = nil,
}
```

**Resultado real**

```
 {
  categories = {},
  framework = "junit4",
  is_disabled = false,
  is_parameterized = false,
  is_repeated = false,
  is_spring = false,
  method = "when_chooseRock_then_beatsScissors",
  nested_chain = {},
  root_class = "GameTest",
  runner = "MockitoJUnitRunner",
  tags = {}
}
```

---

### CT-02 — JUnit 4 spec sin wildcard

**Condición previa**

- Mismo archivo: `GameTest.java`
- Cursor en cualquier línea dentro de la clase

**Comando**

````vim
:lua local ctx = require("custom.test_context").parse() local spec, label = require("custom.test_context").build_spec(ctx, false) print("SPEC:", spec) print("LABEL:", label)```

**Resultado esperado**

````

SPEC: GameTest
LABEL: GameTest [@RunWith(MockitoJUnitRunner)]

```

⚠ NO debe decir `GameTest*` — el wildcard rompe JUnit 4

**Resultado real**

```

SPEC: GameTest
LABEL: GameTest [@RunWith(MockitoJUnitRunner):> [!WARNING]

> ]```

---

### CT-03 — JUnit 4 spec con método

**Condición previa**

- Abrir `GameTest.java`
- Cursor DENTRO del método `when_chooseRock_then_beatsScissors`
  (en cualquier línea dentro de las llaves del método)

**Comando**

```vim
:lua local ctx = require("custom.test_context").parse() local spec, label = require("custom.test_context").build_spec(ctx, true) print("SPEC:", spec) print("METHOD:", ctx.method)
```

**Resultado esperado**

```
SPEC:  GameTest#when_chooseRock_then_beatsScissors
METHOD: when_chooseRock_then_beatsScissors
```

**Resultado real**

```
SPEC: GameTest#when_chooseRock_then_beatsScissors
METHOD: when_chooseRock_then_beatsScissors
```

---

### CT-04 — JUnit 5 clase simple

**Condición previa**

- Abrir `EntityUnitTest.java` (el del proyecto Spring)
- Cursor dentro de la clase raíz, fuera de cualquier método

**Comando**

```vim
:lua
local ctx = require("custom.test_context").parse()
print("framework:", ctx.framework)
print("is_spring:", ctx.is_spring)
print("root_class:", ctx.root_class)
local spec, label = require("custom.test_context").build_spec(ctx, false)
print("SPEC:", spec)
```

**Resultado esperado**

```
framework:  junit5
is_spring:  true
root_class: EntityUnitTest
SPEC:       EntityUnitTest*
```

**Resultado real**

```
framework: junit5
  2   is_spring: true
  3   root_class: EntityUnitTest
  4   SPEC: EntityUnitTest*
```

---

### CT-05 — JUnit 5 con @Nested

**Condición previa**

- Abrir `EntityUnitTest.java`
- Cursor DENTRO de la clase `DoctorTest` (la nested), en cualquier línea

**Comando**

```vim
:lua
local ctx = require("custom.test_context").parse()
print("root_class:", ctx.root_class)
print("nested_chain:", vim.inspect(ctx.nested_chain))
local spec, _ = require("custom.test_context").build_spec(ctx, false)
print("SPEC:", spec)
```

**Resultado esperado**

```

root_class: EntityUnitTest
nested_chain: { "DoctorTest" }
SPEC: EntityUnitTest\$DoctorTest

```

**Resultado real**

```

root_class: EntityUnitTest
2 nested_chain: { "DoctorTest" }
3 SPEC: EntityUnitTest\$DoctorTest

```

---

## Módulo 2: `test_results.lua`

Instalación: reemplazar `~/.config/nvim/lua/custom/test_results.lua`

---

### TR-01 — JUnit 4: classname con fallback a testsuite

**Condición previa**

- Haber corrido `mvn test -Dtest='GameTest'` en el proyecto `testing-clean-code`
  (puede fallar con errores de Mockito — igual genera los XMLs)
- Verificar que el XML existe:

  ```bash
  ls ~/dev/learning/backend/testing-clean-code/target/surefire-reports/
  ``
  ```

### resultados de previa

```bash
[ERROR]   GameTest.when_writeQuit_then_exitGame » Mockito
Mockito cannot mock this class: class java.util.Scanner.
Can not mock final classes with the following settings :
- explicit serialization (e.g. withSettings().serializable())
- extra interfaces (e.g. withSettings().extraInterfaces(...))

You are seeing this disclaimer because Mockito is configured to create inlined mocks.
You can learn about inline mocks and their limitations under item #39 of the Mockito class javadoc.

Underlying exception : org.mockito.exceptions.base.MockitoException: Could not modify all classes [class java.util.Scanner, interface java.lang.AutoCloseable, class java.lang.Object, interface java.io.Closeable, interface java.util.Iterator]
[INFO]
[ERROR] Tests run: 6, Failures: 0, Errors: 6, Skipped: 0
[INFO]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD FAILURE
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  11.342 s
[INFO] Finished at: 2026-03-25T01:11:17-03:00
[INFO] ------------------------------------------------------------------------
[ERROR] Failed to execute goal org.apache.maven.plugins:maven-surefire-plugin:3.5.4:test (default-test) on project testing-clean-code:
[ERROR]


[ERROR] See dump files (if any exist) [date].dump, [date]-jvmRun[N].dump and [date].dumpstream.
[ERROR] -> [Help 1]
[ERROR]
[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
[ERROR] Re-run Maven using the -X switch to enable full debug logging.
[ERROR]
[ERROR] For more information about the errors and possible solutions, please read the following articles:
[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoFailureException


```

```bash
ls ~/dev/learning/backend/testing-clean-code/target/surefire-reports/
TEST-com.course.FizzbuzzTest.xml  TEST-com.course.MoneyUtilTest.xml  com.course.GameTest.txt
TEST-com.course.GameTest.xml      com.course.FizzbuzzTest.txt        com.course.MoneyUtilTest.txt


```

- Abrir Neovim desde la raíz del proyecto:

  ```bash
  cd ~/dev/learning/backend/testing-clean-code && nvim
  ```

**Comando**

```vim
:lua local r = require("custom.test_results") local results = r.get_all_results() print("total:", #results) if results[1] then print("class:", results[1].class) print("name:", results[1].name) end
```

**Resultado esperado**

```
total:  6
class:  com.course.GameTest    ← NO "when_writeQuit..." ni similar
name:   when_writeQuit_then_exitGame
```

**Resultado real**

````
total: 14
class: com.course.FizzbuzzTest
name: should_returnFizz_whenAMultiplerOf3```

---

### TR-02 — JUnit 4: get_results_for_class

**Condición previa**

- Misma que TR-01 (XMLs de GameTest en disco)

**Comando**

```vim
:lua
local results = require("custom.test_results").get_results_for_class("GameTest")
print("encontrados:", #results)
````

**Resultado esperado**

```
encontrados: 6
```

Si dice `0` → el fix del classname no está funcionando

**Resultado real**

```
encontrados: 6
```

---

### TR-03 — JUnit 5: árbol con nested

**Condición previa**

- Haber corrido los tests del proyecto Spring (EntityUnitTest)
- Abrir Neovim desde la raíz de ese proyecto

**Comando**

```vim
:lua local r = require("custom.test_results") local results = r.get_all_results() local roots, order = r.group_as_tree(results) print("clases raíz:", vim.inspect(order)) for _, root in ipairs(order) do print(root, "nested:", vim.inspect(roots[root].nested_order)) end
```

**Resultado esperado**

```
clases raíz: { "EntityUnitTest" }
EntityUnitTest  nested: { "DoctorTest", "PatientTests" }
```

**Resultado real**

```
clases raíz: { "AppointmentControllerUnitTest", "AppointmentJpaUnitTest", "DemoApplicationTests",                     "DoctorControllerUnitTest", "DoctorJpaUnitTest", "EntityUnitTest", "PatientControllerUnitTest",                       "PatientJpaUnitTest", "RoomControllerUnitTest", "RoomJpaUnitTest" }
   5   AppointmentControllerUnitTest nested: {}
   4   AppointmentJpaUnitTest nested: {}
   3   DemoApplicationTests nested: {}
   2   DoctorControllerUnitTest nested: {}
   1   DoctorJpaUnitTest nested: {}
   8   EntityUnitTest nested: { "DoctorTest", "PatientTests" }
   1   PatientControllerUnitTest nested: {}
   2   PatientJpaUnitTest nested: {}
   3   RoomControllerUnitTest nested: {}
   4   RoomJpaUnitTest nested: {}


```

---

## Módulo 3: `test_diff.lua`

Instalación: copiar a `~/.config/nvim/lua/custom/test_diff.lua`
No requiere proyecto Java abierto — se puede testear con strings.

---

### TD-01 — AssertJ assertion

**Condición previa**

- Ninguna — se puede ejecutar desde cualquier buffer

**Comando**

```vim
:lua local diff = require("custom.test_diff") local st = "expected: <5> but was: <3>" print(vim.inspect(diff.extract(st)))
```

**Resultado esperado**

```lua
{
  expected = "5",
  actual = "3",
  kind = "assertion"
}
```

**Resultado real**

```
{
  actual = "3",
  expected = "5",
  kind = "assertion"
}
```

---

### TD-02 — JUnit 4 classic assert

**Condición previa**

- Ninguna

**Comando**

```vim
:lua local diff = require("custom.test_diff") local st = "junit.framework.AssertionFailedError: expected:<5> but was:<3>" print(vim.inspect(diff.extract(st)))
```

**Resultado esperado**

```lua
{
  expected = "5",
  actual = "3",
  kind = "assertion"
}
```

**Resultado real**

```
{
  actual = "3",
  expected = "5",
  kind = "assertion"
}
```

---

### TD-03 — Excepción sin expected/actual

**Condición previa**

- Ninguna

**Comando**

```vim
:lua local diff = require("custom.test_diff") local st = "java.lang.NullPointerException at GameTest.java:42" print(vim.inspect(diff.extract(st)))
```

**Resultado esperado**

```lua
{
  kind = "exception"
}
```

**Resultado real**

```
{
  kind = "exception"
}
```

---

### TD-04 — String vacío

**Condición previa**

- Ninguna

**Comando**

```vim
:lua local diff = require("custom.test_diff") print(vim.inspect(diff.extract(""))) print(vim.inspect(diff.extract(nil)))
```

**Resultado esperado**

```lua
{ kind = "unknown" }
{ kind = "unknown" }
```

**Resultado real**

```
{
  kind = "unknown"
}
{
  kind = "unknown"
}
```

---

## Módulo 4: `test_runner.lua`

Instalación: copiar a `~/.config/nvim/lua/custom/test_runner.lua`

---

### RN-01 — Corre y emite líneas

**Condición previa**

- Abrir Neovim desde la raíz de `testing-clean-code`

  ```bash
  cd ~/dev/learning/backend/testing-clean-code && nvim
  ```

**Comando**

```vim
:lua local runner = require("custom.test_runner") runner.run("GameTest", { cwd = vim.fn.getcwd(), on_line = function(line) print("LINE:", line) end, on_exit = function(code, analysis) print("EXIT CODE:", code) print("ANALYSIS:", vim.inspect(analysis)) end, })
})
```

**Resultado esperado**

- Ver líneas de Maven aparecer en messages (`LINE: [INFO] ...`)
- Al terminar: `EXIT CODE: 1` (porque Mockito falla) y `ANALYSIS: { no_tests = false, ... }`
- Verificar que `surefire-reports/` tiene XMLs nuevos:

  ```bash
  ls -la target/surefire-reports/
  ```

**Resultado real**

```
LINE: Underlying exception : org.mockito.exceptions.base.MockitoException: Could not modify all classes [class java.util.Scanner, interface java.lang.AutoCloseable, class java.lang.Object, interface java.io.Closeable, interface java.util.Iterator]
LINE: [INFO]
LINE: [ERROR] Tests run: 6, Failures: 0, Errors: 6, Skipped: 0
LINE: [INFO]
LINE: [INFO] ------------------------------------------------------------------------
LINE: [INFO] BUILD FAILURE
LINE: [INFO] ------------------------------------------------------------------------
LINE: [INFO] Total time:  3.112 s
LINE: [INFO] Finished at: 2026-03-25T03:37:43-03:00
LINE: [INFO] ------------------------------------------------------------------------
LINE: [ERROR] Failed to execute goal org.apache.maven.plugins:maven-surefire-plugin:3.5.4:test (default-test) on project testing-clean-code:
LINE: [ERROR]
LINE: [ERROR] See /home/jhonayo/dev/learning/backend/testing-clean-code/target/surefire-reports for the individual test results.
LINE: [ERROR] See dump files (if any exist) [date].dump, [date]-jvmRun[N].dump and [date].dumpstream.
LINE: [ERROR] -> [Help 1]
LINE: [ERROR]
LINE: [ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
LINE: [ERROR] Re-run Maven using the -X switch to enable full debug logging.
LINE: [ERROR]
LINE: [ERROR] For more information about the errors and possible solutions, please read the following articles:
LINE: [ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoFailureException
EXIT CODE: 1
ANALYSIS: {
  build_success = false,
  context_failed = false,
  no_tests = false
}

▒▓ ~/dev/learning/backend/testing-clean-code  main *1 ····· 1m 53s  jhonayo@devbox  03:39:14 ▓▒░
❯  ls -la target/surefire-reports/
total 180
drwxrwxr-x+ 2 jhonayo jhonayo  4096 Mar 25 03:37 .
drwxrwxr-x+ 8 jhonayo jhonayo  4096 Mar 25 03:37 ..
-rw-rwxr--+ 1 jhonayo jhonayo 15279 Mar 24 03:15 TEST-com.course.FizzbuzzTest.xml
-rw-rw-r--+ 1 jhonayo jhonayo 74501 Mar 25 03:37 TEST-com.course.GameTest.xml
-rw-rwxr--+ 1 jhonayo jhonayo 14917 Mar 24 02:34 TEST-com.course.MoneyUtilTest.xml
-rw-rwxr--+ 1 jhonayo jhonayo   296 Mar 24 03:15 com.course.FizzbuzzTest.txt
-rw-rwxr--+ 1 jhonayo jhonayo 53749 Mar 25 03:37 com.course.GameTest.txt
-rw-rwxr--+ 1 jhonayo jhonayo   298 Mar 24 02:34 com.course.MoneyUtilTest.txt

░▒▓ ~/dev/learning/backend/testing-clean-code  main *1 ·············· jhonayo@devbox  03:39:17 ▓▒░
❯



```

---

### RN-02 — is_running durante ejecución

**Condición previa**

- Mismo proyecto que RN-01

**Comando**

```vim
:lua local runner = require("custom.test_runner") runner.run("", { cwd = vim.fn.getcwd(), on_line = function() end, on_exit = function() print("terminó") end, }) print("running:", runner.is_running())
```

**Resultado esperado**

```
running: true
(luego aparece "terminó")
```

**Resultado real**

```
running: true
terminó
```

---

### RN-03 — Doble run bloqueado

**Condición previa**

- Mismo proyecto

**Comando**

```vim
:lua local runner = require("custom.test_runner") runner.run("GameTest", { cwd = vim.fn.getcwd(), on_line = function() end, on_exit = function() end }) runner.run("GameTest", { cwd = vim.fn.getcwd(), on_line = function() end, on_exit = function() end })
```

**Resultado esperado**

- Aparece en messages: `Ya hay una ejecución en curso.`
- Solo corre UNA instancia de Maven

**Resultado real**

```
Ya hay una ejecución en curso.
```

---

## Módulo 5: `test_watcher.lua`

Instalación: copiar a `~/.config/nvim/lua/custom/test_watcher.lua`

---

### WT-01 — Detecta XML nuevo

**Condición previa**

- Abrir Neovim desde `testing-clean-code`
- Borrar surefire-reports para partir limpio:

  ```bash
  rm -rf target/surefire-reports
  ```

**Paso 1 — Iniciar watcher desde Neovim:**

```vim
:lua local watcher = require("custom.test_watcher") watcher.start(vim.fn.getcwd() .. "/target/surefire-reports", function(filename) print("XML detectado:", filename) end) print("watcher activo:", watcher.is_active())
```

**Resultado esperado paso 1**

```
watcher activo: true
```

**Paso 2 — Correr Maven desde otra terminal:**

```bash
cd ~/dev/learning/backend/testing-clean-code
mvn test -Dtest='GameTest'
```

**Resultado esperado paso 2**

- En Neovim aparece en messages:

  ```
  XML detectado: TEST-com.course.GameTest.xml
  ```

**Paso 3 — Detener watcher:**

```vim
:lua require("custom.test_watcher").stop() print("activo:", require("custom.test_watcher").is_active())
```

**Resultado esperado paso 3**

```
activo: false
```

**Resultado real**

```
watcher activo: true
XML detectado: TEST-com.course.GameTest.xml
activo: false
```

---

### WT-02 — Debounce: múltiples XMLs = un solo evento

**Condición previa**

- Watcher activo (ejecutar paso 1 de WT-01)
- Proyecto Spring con múltiples clases de test (EntityUnitTest, etc.)

**Comando — correr todos los tests desde terminal externa:**

```bash
cd ~/dev/learning/backend/<proyecto-spring> && ./mvnw test
```

**Resultado esperado**

- Aunque Maven escriba 3-5 XMLs, en Neovim aparecen pocos prints
  (no uno por cada XML — el debounce de 150ms los agrupa)

**Resultado real**

```
[ERROR] Tests run: 6, Failures: 1, Errors: 0, Skipped: 0, Time elapsed: 0.106 s <<< FAILURE! - in com.example.demo.RoomJpaUnitTest
[ERROR] should_find_no_rooms_if_repository_is_empty  Time elapsed: 0.006 s  <<< FAILURE!
java.lang.AssertionError:

Expecting actual not to be empty
        at com.example.demo.RoomJpaUnitTest.should_find_no_rooms_if_repository_is_empty(RoomJpaUnitTest.java:30)

2026-03-25 03:52:57.963  INFO 15619 --- [ionShutdownHook] j.LocalContainerEntityManagerFactoryBean : Closing JPA EntityManagerFactory for persistence unit 'default'
2026-03-25 03:52:57.965  INFO 15619 --- [ionShutdownHook] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown initiated...
2026-03-25 03:52:57.968  INFO 15619 --- [ionShutdownHook] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown completed.
2026-03-25 03:52:57.973  INFO 15619 --- [ionShutdownHook] j.LocalContainerEntityManagerFactoryBean : Closing JPA EntityManagerFactory for persistence unit 'default'
2026-03-25 03:52:57.974  INFO 15619 --- [ionShutdownHook] com.zaxxer.hikari.HikariDataSource       : HikariPool-2 - Shutdown initiated...
2026-03-25 03:52:57.976  INFO 15619 --- [ionShutdownHook] com.zaxxer.hikari.HikariDataSource       : HikariPool-2 - Shutdown completed.
[INFO]
[INFO] Results:
[INFO]
[ERROR] Failures:
[ERROR]   AppointmentControllerUnitTest.shouldCreateAppointment:63 Status expected:<200> but was:<400>
[ERROR]   AppointmentControllerUnitTest.shouldCreateBothAppointmentsConflictDateButNotRoom:145 Status expected:<200> but was:<400>
[ERROR]   AppointmentControllerUnitTest.shouldCreateOneAppointmentOutOfTwoConflictDate:106 Status expected:<200> but was:<400>
[ERROR]   DoctorControllerUnitTest.this_is_a_test:58
expected: false
 but was: true
[ERROR]   EntityUnitTest$DoctorTest.shouldCreateDoctorWithEmptyConstructor:64
[ERROR]   PatientControllerUnitTest.this_is_a_test:78
expected: false
 but was: true
[ERROR]   RoomControllerUnitTest.this_is_a_test:98
expected: false
 but was: true
[ERROR]   RoomJpaUnitTest.should_find_no_rooms_if_repository_is_empty:30
Expecting actual not to be empty
[INFO]
[ERROR] Tests run: 51, Failures: 8, Errors: 0, Skipped: 0
[INFO]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD FAILURE
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  26.165 s
[INFO] Finished at: 2026-03-25T03:52:58-03:00
[INFO] ------------------------------------------------------------------------
[ERROR] Failed to execute goal org.apache.maven.plugins:maven-surefire-plugin:2.22.2:test (default-test) on project accenture-techhub: There are test failures.
[ERROR]
[ERROR] Please refer to /home/jhonayo/dev/learning/backend/nuwe_report/target/surefire-reports for the individual test results.
[ERROR] Please refer to dump files (if any exist) [date].dump, [date]-jvmRun[N].dump and [date].dumpstream.
[ERROR] -> [Help 1]
[ERROR]
[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
[ERROR] Re-run Maven using the -X switch to enable full debug logging.
[ERROR]
[ERROR] For more information about the errors and possible solutions, please read the following articles:
[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoFailureException

░▒▓ ~/dev/learning/backend/nuwe_report  main ·················· 30s  jhonayo@devbox  03:52:58 ▓▒░
❯
```

---

## Resumen de instalación

```bash
# Copiar todos los archivos nuevos
cp test_context.lua ~/.config/nvim/lua/custom/
cp test_runner.lua  ~/.config/nvim/lua/custom/
cp test_watcher.lua ~/.config/nvim/lua/custom/
cp test_diff.lua    ~/.config/nvim/lua/custom/

# Reemplazar el existente (tiene fixes de classname)
cp test_results.lua ~/.config/nvim/lua/custom/
```

Orden de ejecución de tests:

1. CT-01 → CT-05 (test_context)
2. TR-01 → TR-03 (test_results)
3. TD-01 → TD-04 (test_diff)
4. RN-01 → RN-03 (test_runner)
5. WT-01 → WT-02 (test_watcher)

Si todos pasan → podemos integrar todo en `test_ui.lua`
