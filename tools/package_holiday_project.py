from pathlib import Path
import difflib
import json
import zipfile

project = Path(__file__).resolve().parents[1]
artifacts = project / 'artifacts'
artifacts.mkdir(exist_ok=True)
baseline_path = project / '.packaging' / 'ClassManager-v1.0.3-base.zip'
new_files = [
    'lib/models/schedule_adjustment.dart',
    'lib/services/holiday_calendar.dart',
    'lib/services/schedule_resolver.dart',
    'lib/screens/schedule_adjustment_screen.dart',
    'test/holiday_schedule_test.dart',
    'test/holiday_database_test.dart',
    'test/holiday_ui_test.dart',
    'docs/HOLIDAY_REORDER.md',
    'lib/widgets/course_info_dialog.dart',
    'test/course_info_dialog_test.dart',
    'tools/package_holiday_project.py',
    'tools/package.ps1',
    'AGENTS.md',
    'lib/widgets/glass_dialog.dart',
    'test/future_holiday_test.dart',
    'test/glass_dialog_flow_test.dart',
    'lib/widgets/glass_backdrop.dart',
    'shaders/liquid_glass.frag',
    'test/glass_optics_test.dart',
    'docs/LIQUID_GLASS.md',
    'THIRD_PARTY_NOTICES.md',
    'tools/glass_preview_test.dart',
    'lib/theme/lens_material.dart',
    'lib/widgets/lens_motion.dart',
    'lib/widgets/lens_reflection.dart',
    'lib/widgets/lens_dock.dart',
    'lib/widgets/lens_backdrop_refraction.dart',
    'lib/widgets/lens_rail.dart',
    'test/lens_controls_test.dart',
    'test/lens_backdrop_refraction_test.dart',
    'test/glass_scroll_regression_test.dart',
    'test/lens_material_test.dart',
    'licenses/design-systems-LICENSE.txt',
    'lib/config/release_metadata.dart',
    'lib/models/update_manifest.dart',
    'lib/services/quark_update_service.dart',
    'lib/widgets/update_check_dialog.dart',
    'test/support/update_fakes.dart',
    'test/update_manifest_test.dart',
    'test/quark_update_service_test.dart',
    'test/update_check_dialog_test.dart',
    'tools/check_quark_update.dart',
    'docs/UPDATE_CHECK.md',
    'docs/update-manifest.example.json',
    'lib/models/agenda_event.dart',
    'lib/services/agenda_timeline.dart',
    'lib/screens/agenda_edit_screen.dart',
    'lib/widgets/agenda_event_dialog.dart',
    'lib/widgets/agenda_view.dart',
    'test/agenda_event_test.dart',
    'test/agenda_database_test.dart',
    'test/agenda_ui_test.dart',
    'tools/agenda_preview_test.dart',
    'docs/AGENDA.md',
]
patch_parts = []
changes = []
with zipfile.ZipFile(baseline_path) as baseline:
    baseline_files = [i.filename for i in baseline.infolist() if not i.is_dir()]
    for name in sorted(set(baseline_files + new_files)):
        previous = baseline.read(name) if name in baseline_files else b''
        current = (project / name).read_bytes()
        if previous == current:
            continue
        try:
            old_lines = previous.decode('utf-8-sig').replace('\r\n', '\n').splitlines(keepends=True)
            new_lines = current.decode('utf-8-sig').replace('\r\n', '\n').splitlines(keepends=True)
        except UnicodeDecodeError:
            raise RuntimeError(f'Unexpected binary change: {name}')
        if old_lines == new_lines:
            continue
        patch_parts.append(f'diff --git a/{name} b/{name}\n')
        if name not in baseline_files:
            patch_parts.append('new file mode 100644\n')
        patch_parts.extend(difflib.unified_diff(
            old_lines, new_lines,
            fromfile=f'a/{name}' if name in baseline_files else '/dev/null',
            tofile=f'b/{name}',
        ))
        changes.append(name)
    selected = sorted(set(baseline_files + new_files))
    source_zip = artifacts / 'ClassManager-v1.1.0-source.zip'
    with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in selected:
            archive.write(project / name, f'ClassManager-New/{name}')

patch_path = artifacts / 'ClassManager-v1.0.3-to-v1.1.0.patch'
patch_path.write_text(''.join(patch_parts), encoding='utf-8', newline='\n')
print(json.dumps({'changed_files': changes, 'patch': str(patch_path),
                  'source_zip': str(source_zip), 'patch_bytes': patch_path.stat().st_size},
                 ensure_ascii=False, indent=2))
