-- Tests for private-ruby.detect module
local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

-- Helper: load fixture into a buffer and return bufnr
local function load_fixture(fixture_name)
  local path = vim.fn.getcwd() .. '/tests/fixtures/' .. fixture_name
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.fn.readfile(path)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

-- Helper: find mark by method name
local function find_mark_by_method(marks, method_name)
  for _, mark in ipairs(marks) do
    if mark.method_name == method_name then
      return mark
    end
  end
  return nil
end

-- Helper: get all method names from marks
local function get_method_names(marks)
  local names = {}
  for _, mark in ipairs(marks) do
    table.insert(names, mark.method_name)
  end
  return names
end

T['detect'] = new_set()

T['detect']['basic.rb'] = new_set()

T['detect']['basic.rb']['detects private methods after private keyword'] = function()
  -- GIVEN: basic.rb fixture with one public method, private section, two private methods
  local bufnr = load_fixture('basic.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: only private_method_one and private_method_two are marked
  local method_names = get_method_names(marks)
  expect.equality(#marks, 2)
  expect.equality(vim.tbl_contains(method_names, 'private_method_one'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_method_two'), true)
  expect.equality(vim.tbl_contains(method_names, 'public_method'), false)
end

T['detect']['basic.rb']['returns correct line numbers'] = function()
  -- GIVEN: basic.rb fixture
  local bufnr = load_fixture('basic.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: line numbers are 0-based and correct
  local mark_one = find_mark_by_method(marks, 'private_method_one')
  local mark_two = find_mark_by_method(marks, 'private_method_two')

  -- Line 9 (0-based: 8) is "def private_method_one"
  expect.equality(mark_one.lnum, 8)
  -- Line 13 (0-based: 12) is "def private_method_two"
  expect.equality(mark_two.lnum, 12)
end

T['detect']['nested.rb'] = new_set()

T['detect']['nested.rb']['handles nested class scope correctly'] = function()
  -- GIVEN: nested.rb fixture with module + nested class
  local bufnr = load_fixture('nested.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: inner_private and module_private are marked; publics are not
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'inner_private'), true)
  expect.equality(vim.tbl_contains(method_names, 'module_private'), true)
  expect.equality(vim.tbl_contains(method_names, 'module_public'), false)
  expect.equality(vim.tbl_contains(method_names, 'inner_public'), false)
end

T['detect']['nested.rb']['private state resets per scope'] = function()
  -- GIVEN: nested.rb where private in InnerClass doesn't leak to OuterModule
  local bufnr = load_fixture('nested.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: exactly 2 private methods (inner_private, module_private)
  expect.equality(#marks, 2)
end

T['detect']['singleton.rb'] = new_set()

T['detect']['singleton.rb']['detects private instance methods'] = function()
  -- GIVEN: singleton.rb fixture
  local bufnr = load_fixture('singleton.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: instance_private is marked
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'instance_private'), true)
  expect.equality(vim.tbl_contains(method_names, 'instance_public'), false)
end

T['detect']['singleton.rb']['does not mark def self.x under instance private'] = function()
  -- GIVEN: singleton.rb where "private" in class scope only affects instance methods
  local bufnr = load_fixture('singleton.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: singleton_public (def self.singleton_public) is NOT marked as private
  -- because instance-level "private" doesn't affect class methods
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'singleton_public'), false)
end

T['detect']['singleton.rb']['detects private in class << self block'] = function()
  -- GIVEN: singleton.rb with class << self block containing private
  local bufnr = load_fixture('singleton.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: singleton_in_block_private is marked; singleton_in_block_public is not
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'singleton_in_block_private'), true)
  expect.equality(vim.tbl_contains(method_names, 'singleton_in_block_public'), false)
end

T['detect']['singleton.rb']['marks methods inside class << self as singleton'] = function()
  -- GIVEN: singleton.rb with class << self block
  local bufnr = load_fixture('singleton.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: singleton_in_block_private has is_singleton = true
  local mark = find_mark_by_method(marks, 'singleton_in_block_private')
  expect.equality(mark.is_singleton, true)
end

T['detect']['complex.rb'] = new_set()

T['detect']['complex.rb']['detects all private methods in large file'] = function()
  -- GIVEN: complex.rb fixture with ~300 lines, multiple nested modules/classes
  local bufnr = load_fixture('complex.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: all private methods are detected
  local method_names = get_method_names(marks)

  -- UserAuthenticator private methods
  expect.equality(vim.tbl_contains(method_names, 'user_valid?'), true)
  expect.equality(vim.tbl_contains(method_names, 'password_matches?'), true)
  expect.equality(vim.tbl_contains(method_names, 'create_session_token'), true)
  expect.equality(vim.tbl_contains(method_names, 'invalidate_session'), true)
  expect.equality(vim.tbl_contains(method_names, 'clear_cookies'), true)
  expect.equality(vim.tbl_contains(method_names, 'session_valid?'), true)
  expect.equality(vim.tbl_contains(method_names, 'token_not_expired?'), true)
  expect.equality(vim.tbl_contains(method_names, 'generate_new_token'), true)
  expect.equality(vim.tbl_contains(method_names, 'store_token_in_redis'), true)
  expect.equality(vim.tbl_contains(method_names, 'remove_token_from_redis'), true)
  expect.equality(vim.tbl_contains(method_names, 'redis_token_ttl'), true)
  expect.equality(vim.tbl_contains(method_names, 'rotate_token'), true)
  expect.equality(vim.tbl_contains(method_names, 'log_authentication_attempt'), true)
  expect.equality(vim.tbl_contains(method_names, 'log_token_rotation'), true)

  -- TokenValidator private methods
  expect.equality(vim.tbl_contains(method_names, 'decode_token'), true)
  expect.equality(vim.tbl_contains(method_names, 'enhanced_payload'), true)
  expect.equality(vim.tbl_contains(method_names, 'handle_decode_error'), true)
  expect.equality(vim.tbl_contains(method_names, 'suspicious_error?'), true)
  expect.equality(vim.tbl_contains(method_names, 'notify_security_team'), true)

  -- PermissionChecker private methods
  expect.equality(vim.tbl_contains(method_names, 'has_permission?'), true)
  expect.equality(vim.tbl_contains(method_names, 'permission_key'), true)
  expect.equality(vim.tbl_contains(method_names, 'admin?'), true)
  expect.equality(vim.tbl_contains(method_names, 'admin_or_owner?'), true)
  expect.equality(vim.tbl_contains(method_names, 'owner?'), true)

  -- RoleManager private methods
  expect.equality(vim.tbl_contains(method_names, 'valid_role?'), true)
  expect.equality(vim.tbl_contains(method_names, 'can_assign_role?'), true)
  expect.equality(vim.tbl_contains(method_names, 'current_role_index'), true)
  expect.equality(vim.tbl_contains(method_names, 'update_user_role'), true)
  expect.equality(vim.tbl_contains(method_names, 'clear_permission_cache'), true)
  expect.equality(vim.tbl_contains(method_names, 'notify_role_change'), true)
end

T['detect']['complex.rb']['does not detect public methods'] = function()
  -- GIVEN: complex.rb fixture
  local bufnr = load_fixture('complex.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: public methods are NOT marked
  local method_names = get_method_names(marks)

  -- Public methods should not be in the list
  expect.equality(vim.tbl_contains(method_names, 'initialize'), false)
  expect.equality(vim.tbl_contains(method_names, 'authenticate'), false)
  expect.equality(vim.tbl_contains(method_names, 'logout'), false)
  expect.equality(vim.tbl_contains(method_names, 'refresh_token'), false)
  expect.equality(vim.tbl_contains(method_names, 'validate'), false)
  expect.equality(vim.tbl_contains(method_names, 'generate'), false)
  expect.equality(vim.tbl_contains(method_names, 'can_read?'), false)
  expect.equality(vim.tbl_contains(method_names, 'can_write?'), false)
  expect.equality(vim.tbl_contains(method_names, 'can_delete?'), false)
  expect.equality(vim.tbl_contains(method_names, 'can_manage?'), false)
  expect.equality(vim.tbl_contains(method_names, 'assign_role'), false)
  expect.equality(vim.tbl_contains(method_names, 'promote'), false)
  expect.equality(vim.tbl_contains(method_names, 'demote'), false)
  expect.equality(vim.tbl_contains(method_names, 'success?'), false)
  expect.equality(vim.tbl_contains(method_names, 'failure?'), false)
  expect.equality(vim.tbl_contains(method_names, 'cache_key'), false)
  expect.equality(vim.tbl_contains(method_names, 'cached_data'), false)
  expect.equality(vim.tbl_contains(method_names, 'track_event'), false)
end

T['detect']['complex.rb']['detects private singleton methods in class << self'] = function()
  -- GIVEN: complex.rb with ServiceResult class << self block
  local bufnr = load_fixture('complex.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: private class methods are detected and marked as singleton
  local build_mark = find_mark_by_method(marks, 'build_from_exception')
  local wrap_mark = find_mark_by_method(marks, 'wrap_errors')
  local normalize_mark = find_mark_by_method(marks, 'normalize_error')

  expect.equality(build_mark ~= nil, true)
  expect.equality(build_mark.is_singleton, true)
  expect.equality(wrap_mark ~= nil, true)
  expect.equality(wrap_mark.is_singleton, true)
  expect.equality(normalize_mark ~= nil, true)
  expect.equality(normalize_mark.is_singleton, true)
end

T['detect']['complex.rb']['returns correct total count'] = function()
  -- GIVEN: complex.rb fixture
  local bufnr = load_fixture('complex.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: total count matches expected private methods
  -- Count: UserAuthenticator(14) + TokenValidator(5) + PermissionChecker(5) +
  --        RoleManager(6) + ServiceResult singleton(3) + Cacheable(4) + Trackable(4) = 41
  expect.equality(#marks, 41)
end

T['detect']['operators.rb'] = new_set()

T['detect']['operators.rb']['detects private operator methods'] = function()
  -- GIVEN: operators.rb fixture with operator and indexer methods
  local bufnr = load_fixture('operators.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: private operator methods are detected
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, '-'), true)
  expect.equality(vim.tbl_contains(method_names, '*'), true)
  expect.equality(vim.tbl_contains(method_names, '[]='), true)
  expect.equality(vim.tbl_contains(method_names, '<=>'), true)
  expect.equality(vim.tbl_contains(method_names, '=='), true)

  -- Public operator methods should not be marked
  expect.equality(vim.tbl_contains(method_names, '+'), false)
  expect.equality(vim.tbl_contains(method_names, '[]'), false)
end

T['detect']['endless.rb'] = new_set()

T['detect']['endless.rb']['detects private endless methods'] = function()
  -- GIVEN: endless.rb fixture with Ruby 3.0 endless method syntax
  local bufnr = load_fixture('endless.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: private endless methods are detected
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'private_getter'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_with_arg'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_with_args'), true)

  -- Public endless methods should not be marked
  expect.equality(vim.tbl_contains(method_names, 'public_getter'), false)
  expect.equality(vim.tbl_contains(method_names, 'public_with_arg'), false)
end

T['detect']['endless.rb']['scope tracking works after endless methods'] = function()
  -- GIVEN: endless.rb where regular methods follow endless methods
  local bufnr = load_fixture('endless.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: regular_private is still detected (endless methods don't break scope)
  -- and back_to_public is NOT detected (visibility was reset to public)
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'regular_private'), true)
  expect.equality(vim.tbl_contains(method_names, 'back_to_public'), false)
end

T['detect']['blocks.rb'] = new_set()

T['detect']['blocks.rb']['do/end blocks do not break scope tracking'] = function()
  -- GIVEN: blocks.rb with lambda do/end blocks before private section
  local bufnr = load_fixture('blocks.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: all three private methods are detected
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'private_one'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_two'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_three'), true)

  -- Public method should not be marked
  expect.equality(vim.tbl_contains(method_names, 'public_method'), false)

  -- Total count should be exactly 3
  expect.equality(#marks, 3)
end

T['detector'] = new_set()

T['detector']['config selection'] = new_set()

T['detector']['config selection']['regex mode uses regex detector'] = function()
  -- GIVEN: config set to regex mode
  local config = require('private-ruby.config')
  config.setup({ detect = { kind = 'regex' } })

  local bufnr = load_fixture('basic.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: detection works (regex path)
  expect.equality(#marks, 2)
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'private_method_one'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_method_two'), true)

  -- Reset config
  config.setup({})
end

T['detector']['config selection']['treesitter mode uses treesitter detector'] = function()
  -- GIVEN: config set to treesitter mode (default)
  local config = require('private-ruby.config')
  config.setup({ detect = { kind = 'treesitter' } })

  local bufnr = load_fixture('basic.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: detection works (treesitter path when available, regex fallback otherwise)
  expect.equality(#marks, 2)
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'private_method_one'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_method_two'), true)

  -- Reset config
  config.setup({})
end

T['detector']['config selection']['auto mode falls back to regex when treesitter unavailable'] = function()
  -- GIVEN: config set to auto mode and treesitter forced to fail
  local config = require('private-ruby.config')
  config.setup({ detect = { kind = 'auto' } })

  -- Temporarily make treesitter unavailable by mocking
  local ts_detect = require('private-ruby.detect.treesitter')
  local original_detect = ts_detect.detect
  ts_detect.detect = function()
    return nil
  end

  local bufnr = load_fixture('basic.rb')
  local detect = require('private-ruby.detect')

  -- WHEN: calling detect (should fallback to regex)
  local marks = detect.detect(bufnr)

  -- THEN: detection still works via regex fallback
  expect.equality(#marks, 2)
  local method_names = get_method_names(marks)
  expect.equality(vim.tbl_contains(method_names, 'private_method_one'), true)
  expect.equality(vim.tbl_contains(method_names, 'private_method_two'), true)

  -- Restore original
  ts_detect.detect = original_detect
  config.setup({})
end

T['detector']['config selection']['invalid config kind falls back to default'] = function()
  -- GIVEN: config with invalid kind
  local config = require('private-ruby.config')
  config.setup({ detect = { kind = 'invalid_value' } })

  -- THEN: kind should be reset to default
  local cfg = config.get()
  expect.equality(cfg.detect.kind, 'treesitter')

  -- Reset config
  config.setup({})
end

return T
