# (c) 2017 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
# https://github.com/ansible/ansible/blob/v2.8.4/lib/ansible/plugins/callback/debug.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = '''
    callback: human_readable_stdout
    type: stdout
    short_description: formatted stdout/stderr display
    description:
      - Use this callback to sort through extensive debug output
    version_added: "2.4"
    extends_documentation_fragment:
      - default_callback
    requirements:
      - set as stdout in configuration
'''

import json

from ansible.parsing.ajson import AnsibleJSONEncoder
from ansible.plugins.callback.default import CallbackModule as CallbackModule_default


class CallbackModule(CallbackModule_default):  # pylint: disable=too-few-public-methods,no-init
    '''
    Override for the default callback module.

    Render std err/out outside of the rest of the result which it prints with
    indentation.
    '''
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'human_readable_stdout'

    def _dump_results(self, result, indent=None, sort_keys=True, keep_invocation=False):
        '''Return the text to output for a result.'''

        # Enable JSON identation
        result['_ansible_verbose_always'] = True

        save = {}
        for key in ['stdout', 'stdout_lines', 'stderr', 'stderr_lines', 'msg', 'module_stdout', 'module_stderr']:
            if key in result:
                save[key] = result.pop(key)

        output = CallbackModule_default._dump_results(self, result)

        for key in ['stdout', 'stderr', 'msg', 'module_stdout', 'module_stderr']:
            if key in save and save[key]:
                output += '\n\n%s:\n\n%s\n' % (key.upper(), save[key])

        for key, value in save.items():
            result[key] = value

        return output

    def _get_item_label(self, result):
        ''' retrieves the value to be displayed as a label for an item entry from a result object'''
        if result.get('_ansible_no_log', False):
            item = "(censored due to no_log)"
        else:
            item = result.get('_ansible_item_label', result.get('item'))
            if not isinstance(item, basestring):
                if (self._display.verbosity > 0 or '_ansible_verbose_always' in result) and '_ansible_verbose_override' not in result:
                    item = json.dumps(item, cls=AnsibleJSONEncoder, indent=4, ensure_ascii=False, sort_keys=True)

        return item

    def v2_runner_on_ok(self, result):
        if 'no_print_action' not in result._task.tags or 'print_action' in result._task.tags or (self._display.verbosity > 1 or '_ansible_verbose_always' in result._result):
            CallbackModule_default.v2_runner_on_ok(self, result)

    def v2_runner_on_skipped(self, result):
        if ('no_print_skip_action' not in result._task.tags and 'no_print_action' not in result._task.tags) or 'print_action' in result._task.tags or (self._display.verbosity > 1 or '_ansible_verbose_always' in result._result):
            CallbackModule_default.v2_runner_on_skipped(self, result)

    def v2_runner_item_on_ok(self, result):
        if 'no_print_action' not in result._task.tags or 'print_action' in result._task.tags or (self._display.verbosity > 1 or '_ansible_verbose_always' in result._result):
            CallbackModule_default.v2_runner_item_on_ok(self, result)

    def v2_runner_item_on_skipped(self, result):
        if ('no_print_skip_action' not in result._task.tags and 'no_print_action' not in result._task.tags) or 'print_action' in result._task.tags or (self._display.verbosity > 1 or '_ansible_verbose_always' in result._result):
            CallbackModule_default.v2_runner_item_on_skipped(self, result)

    def v2_playbook_on_task_start(self, task, is_conditional):
        if (not task.get_name().strip().endswith('no_print_action') and 'no_print_action' not in task.tags) or 'print_action' in task.tags or self._display.verbosity > 1:
            CallbackModule_default.v2_playbook_on_task_start(self, task, is_conditional)

    def v2_playbook_on_include(self, included_file):
        if not included_file._filename.endswith('async_job_watcher/tasks/recursive.yml') and not included_file._filename.endswith('async_job_watcher/tasks/end.yml'):
            CallbackModule_default.v2_playbook_on_include(self, included_file)
