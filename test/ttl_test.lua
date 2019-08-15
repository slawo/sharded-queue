local helper = require('test.helper')
local queue = require('queue')
local fiber = require('fiber')

local t = require('luatest')

local g = t.group('ttl_test')

g.before_all = function()
    queue.init('localhost:3301')
end

g.after_all = function()
    queue.stop()
end

--
function g.test_touch_task()
    local tube_name = 'touch_task_test'
    local tube = queue.create_tube(tube_name)

    local task = tube:put('simple data', { ttl = 0.2, ttr = 0.1 })
    t.assert_equals(task[helper.index.data], 'simple data')

    local touched_task = tube:touch(task[helper.index.task_id], 0.8)
    t.assert_equals(
        helper.round(tonumber(helper.sec(touched_task[helper.index.ttl])), 0.01), 1)
    fiber.sleep(0.5)
    local taken_task = tube:take()
    t.assert_equals(taken_task[helper.index.task_id], task[helper.index.task_id])
end


function g.test_delayed_tasks()
    local tube_name = 'delayed_tasks_test'
    local tube = queue.create_tube(tube_name)

    -- task delayed for 0.1 sec 
    local task = tube:put('simple data', { delay = 1, ttl = 1, ttr = 0.1 })

    -- delayed task was not taken
    t.assert_equals(task[helper.index.status], helper.state.DELAYED)
    t.assert_equals(tube:take(0.001), nil)

    -- delayed task was taken after timeout
    local taken_task = tube:take(1)
    -- t.assert_equals(task[3], helper.state.TAKEN)
    t.assert_equals(task[helper.index.data], 'simple data')

    -- retake task before ttr
    t.assert_equals(tube:take(0.01), nil)

    -- retake task after ttr
    t.assert_equals(tube:take(0.1)[helper.index.data], 'simple data')
end