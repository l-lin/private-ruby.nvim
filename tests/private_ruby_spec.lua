-- Tests for private_ruby.detect module
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
  local detect = require('private_ruby.detect')

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
  local detect = require('private_ruby.detect')

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
  local detect = require('private_ruby.detect')

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
  local detect = require('private_ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: exactly 2 private methods (inner_private, module_private)
  expect.equality(#marks, 2)
end

T['detect']['singleton.rb'] = new_set()

T['detect']['singleton.rb']['detects private instance methods'] = function()
  -- GIVEN: singleton.rb fixture
  local bufnr = load_fixture('singleton.rb')
  local detect = require('private_ruby.detect')

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
  local detect = require('private_ruby.detect')

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
  local detect = require('private_ruby.detect')

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
  local detect = require('private_ruby.detect')

  -- WHEN: calling detect
  local marks = detect.detect(bufnr)

  -- THEN: singleton_in_block_private has is_singleton = true
  local mark = find_mark_by_method(marks, 'singleton_in_block_private')
  expect.equality(mark.is_singleton, true)
end

return T
