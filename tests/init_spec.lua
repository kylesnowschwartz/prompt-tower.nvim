-- tests/init_spec.lua
-- Tests for the main init module

local helpers = require('tests.helpers')
local prompt_tower = require('prompt-tower')

describe('prompt-tower.init', function()
  before_each(function()
    prompt_tower._reset_state()
  end)

  describe('setup', function()
    it('should initialize successfully with default options', function()
      local success = prompt_tower.setup()
      assert.is_true(success)

      local state = prompt_tower._get_state()
      assert.is_true(state.initialized)
    end)

    it('should initialize successfully with custom options', function()
      local success = prompt_tower.setup({
        max_file_size_kb = 512,
        ui = { title = 'Custom Prompt Tower' },
      })
      assert.is_true(success)
    end)

    it('should validate setup options', function()
      assert.has_error(function()
        prompt_tower.setup('invalid_options')
      end)
    end)
  end)

  describe('select_current_file', function()
    it('should auto-initialize if not setup', function()
      -- Don't call setup first
      local state_before = prompt_tower._get_state()
      assert.is_false(state_before.initialized)

      -- Create a test buffer with a file
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_buf_set_name(buf, '/tmp/test_file.txt')
      vim.api.nvim_set_current_buf(buf)

      prompt_tower.select_current_file()

      local state_after = prompt_tower._get_state()
      assert.is_true(state_after.initialized)
    end)

    it('should add current file to selection', function()
      prompt_tower.setup()

      local test_file = helpers.fs.get_real_workspace_file(helpers.TEST_PATHS.readme)
      helpers.fs.create_test_buffer(test_file)

      prompt_tower.select_current_file()

      local workspace = prompt_tower._get_workspace()
      helpers.assert.file_selected(workspace, test_file)
    end)

    it('should handle empty buffer name gracefully', function()
      prompt_tower.setup()

      helpers.fs.create_test_buffer('')

      assert.has_no_error(function()
        prompt_tower.select_current_file()
      end)

      local workspace = prompt_tower._get_workspace()
      helpers.assert.selection_count(workspace, 0)
    end)
  end)

  describe('toggle_selection', function()
    before_each(function()
      prompt_tower.setup()
    end)

    it('should add file when not selected', function()
      -- Use a real file from our workspace
      local test_file = vim.fn.getcwd() .. '/README.md'
      prompt_tower.toggle_selection(test_file)

      local workspace = prompt_tower._get_workspace()
      assert.is_true(workspace.is_file_selected(test_file))
    end)

    it('should remove file when already selected', function()
      -- Use a real file from our workspace
      local test_file = vim.fn.getcwd() .. '/README.md'

      -- First add the file
      prompt_tower.toggle_selection(test_file)
      local workspace = prompt_tower._get_workspace()
      assert.is_true(workspace.is_file_selected(test_file))

      -- Then remove it
      prompt_tower.toggle_selection(test_file)
      assert.is_false(workspace.is_file_selected(test_file))
    end)

    it('should use current file when no filepath provided', function()
      -- Create a test buffer with a real file
      local test_file = vim.fn.getcwd() .. '/Makefile' -- Use different file to avoid name collision
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_buf_set_name(buf, test_file)
      vim.api.nvim_set_current_buf(buf)

      prompt_tower.toggle_selection()

      local workspace = prompt_tower._get_workspace()
      assert.is_true(workspace.is_file_selected(test_file))
    end)
  end)

  describe('clear_selection', function()
    it('should remove all selected files', function()
      prompt_tower.setup()

      -- Add some real files
      local file1 = vim.fn.getcwd() .. '/README.md'
      local file2 = vim.fn.getcwd() .. '/Makefile'
      prompt_tower.toggle_selection(file1)
      prompt_tower.toggle_selection(file2)

      local workspace = prompt_tower._get_workspace()
      assert.equals(2, workspace.get_selection_count())

      -- Clear selection
      prompt_tower.clear_selection()

      assert.equals(0, workspace.get_selection_count())
    end)
  end)

  describe('generate_context', function()
    before_each(function()
      prompt_tower.setup()
    end)

    it('should generate context for selected files', function()
      -- Add some real files
      local file1 = vim.fn.getcwd() .. '/README.md'
      prompt_tower.toggle_selection(file1)

      prompt_tower.generate_context()

      local state = prompt_tower._get_state()
      assert.is_not_nil(state.last_context)
      assert.is_true(string.find(state.last_context, 'README.md') ~= nil)
    end)

    it('should warn when no files selected', function()
      -- Don't add any files
      assert.has_no_error(function()
        prompt_tower.generate_context()
      end)

      local state = prompt_tower._get_state()
      assert.is_nil(state.last_context)
    end)

    it('should include proper XML structure', function()
      local file1 = vim.fn.getcwd() .. '/README.md'
      prompt_tower.toggle_selection(file1)
      prompt_tower.generate_context()

      local state = prompt_tower._get_state()
      -- Check for XML template format structure
      assert.is_true(string.find(state.last_context, '<file name="README.md" path="README.md">') ~= nil)
      assert.is_true(string.find(state.last_context, '</file>') ~= nil)
    end)
  end)

  describe('template_engine', function()
    it('should return nil for non-existent files', function()
      local template_engine = require('prompt-tower.services.template_engine')
      local content = template_engine._read_file('/non/existent/file.txt')
      assert.is_nil(content)
    end)
  end)

  describe('_get_state', function()
    it('should return current internal state', function()
      local state = prompt_tower._get_state()
      assert.is_table(state)
      assert.is_boolean(state.initialized)
    end)
  end)

  describe('_reset_state', function()
    it('should reset to initial state', function()
      prompt_tower.setup()
      local test_file = vim.fn.getcwd() .. '/README.md'
      prompt_tower.toggle_selection(test_file)

      local state_before = prompt_tower._get_state()
      local workspace_before = prompt_tower._get_workspace()
      assert.is_true(state_before.initialized)
      assert.equals(1, workspace_before.get_selection_count())

      prompt_tower._reset_state()

      local state_after = prompt_tower._get_state()
      local workspace_after = prompt_tower._get_workspace()
      assert.is_false(state_after.initialized)
      assert.equals(0, workspace_after.get_selection_count())
    end)
  end)
end)
