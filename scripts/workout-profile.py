#!/usr/bin/env python3
"""Dependency-free simulator profiling runner and durable, honest trend charts."""
import argparse
import datetime as dt
import hashlib
import html
import json
import os
from pathlib import Path
import shutil
import signal
import time
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / 'docs/performance/runs'
BUNDLE = 'com.cseibert.StrengthLog'


def command(args, **kwargs):
    return subprocess.check_output(args, cwd=ROOT, text=True, **kwargs).strip()


def percentile(values, fraction):
    values = sorted(values)
    if not values:
        return None
    index = (len(values) - 1) * fraction
    lo = int(index)
    hi = min(lo + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (index - lo)


def summarize(samples):
    result = {}
    # Sequence 1 starts the timer; shared sequence 2 catches others up. Both are setup.
    for kind in ('individual', 'shared'):
        records = [s for s in samples if s.get('type') == 'completion'
                   and s.get('kind') == kind and s.get('completing')
                   and (s.get('snapshot_succeeded') or s.get('render_checkpoint_succeeded')) and s['sequence'] > (3 if kind == 'shared' else 2)]
        # Keep individual warmups from other scenarios out of the result.
        records = [s for s in records if s.get('scenario') == kind]
        result[kind] = {'n': len(records)}
        for key in ('handler_ms', 'view_update_ms', 'next_frame_callback_ms',
                    'rendered_snapshot_ms', 'snapshot_capture_ms'):
            values = [s[key] for s in records if key in s]
            if values:
                result[kind][key] = {'median': statistics.median(values),
                                    'p95': percentile(values, .95), 'max': max(values)}
        phases = sorted({key for s in records for key in s.get('phases_ms', {})})
        result[kind]['phase_medians_ms'] = {
            key: statistics.median([s.get('phases_ms', {}).get(key, 0) for s in records])
            for key in phases} if records else {}
    scroll = [s for s in samples if s.get('type') == 'scroll']
    result['scroll'] = [{key: s[key] for key in (
        'duration_s', 'callback_fps', 'callback_hitch_count',
        'callback_hitch_ratio_ms_per_s', 'callback_worst_ms', 'motion_duration_s',
        'motion_callback_fps', 'motion_callback_hitch_count',
        'motion_callback_hitch_ratio_ms_per_s', 'motion_callback_worst_ms') if key in s} for s in scroll]
    return result


def graph():
    RUNS.mkdir(parents=True, exist_ok=True)
    runs = [json.loads(p.read_text()) for p in sorted(RUNS.glob('*.json'))]
    # Compare only matched fixture/build profiles; failed/empty runs remain in the ledger.
    groups = {}
    for run in runs:
        if run.get('status') != 'passed':
            continue
        profile = run['profile']
        key = json.dumps(profile, sort_keys=True)
        groups.setdefault(key, []).append(run)
    output = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Workout performance history</title>',
              '<style>body{font:15px system-ui;margin:24px auto;padding:0 20px;max-width:1100px;color:#203044;background:#fff}svg{width:100%;height:auto}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f4f6f8;padding:12px}table{border-collapse:collapse;width:100%}td,th{padding:8px;border:1px solid #ddd;text-align:left;overflow-wrap:anywhere}a{color:#08699e}.table{overflow-x:auto}h2{border-top:1px solid #ddd;padding-top:24px}</style>',
              '<h1>Workout performance history</h1>',
              '<p>Pixel latency uses recorded badge changes and an optical device clock, with approximately one 60-Hz frame of uncertainty plus capture gaps. It begins at the app action handler, not finger contact. CADisplayLink charts show callback cadence, not GPU frames. Missing rendered-hitch metrics stay missing. Points are warmed medians; orange whiskers extend to observed maxima, not confidence intervals. Five samples are descriptive.</p><p><a href="../active-workout-performance-findings-2026-10-07.md">Read the findings and measurement contract</a>. Charts group matching collection versions/configurations. Time labels are UTC; labels and raw data are in the run table.</p>']
    for key, group in groups.items():
        output.append('<h2>Matched profile</h2><pre>' + html.escape(key) + '</pre>')
        specs = [('individual', 'pixel_visual_latency_ms', 'Individual action to visible badge pixels (ms)', 100),
                 ('shared', 'pixel_visual_latency_ms', 'Shared action to all visible badge pixels (ms)', 100),
                 ('individual', 'handler_ms', 'Individual synchronous handler (ms)', None),
                 ('shared', 'handler_ms', 'Shared synchronous handler (ms)', None),
                 ('individual', 'save', 'Individual save phase (ms)', None),
                 ('shared', 'save', 'Shared save phase (ms)', None),
                 ('scroll', 'motion_callback_fps', 'Main callbacks during UIKit scrolling (FPS proxy)', None),
                 ('scroll', 'motion_callback_hitch_ratio_ms_per_s', 'Callbacks during UIKit scrolling: hitch ratio proxy (ms/s)', 5),
                 ('scroll', 'motion_callback_hitch_count', 'Callbacks during UIKit scrolling: hitch count proxy', None),
                 ('scroll', 'motion_callback_worst_ms', 'Callbacks during UIKit scrolling: worst gap (ms)', None)]
        for kind, metric, title, target in specs:
            values, maxima = [], []
            for run in group:
                summary = run['summary'].get(kind, {})
                if kind == 'scroll':
                    val = summary[0].get(metric) if summary else None
                elif metric == 'save':
                    val = summary.get('phase_medians_ms', {}).get('save')
                else:
                    val = summary.get(metric, {}).get('median')
                values.append(val)
                maxima.append(summary.get(metric, {}).get('max') if kind != 'scroll' and metric != 'save' else None)
            if not any(v is not None for v in values):
                continue
            ymax = max([v for v in values + maxima if v is not None] + [target or 0, 1]) * 1.15
            output.append('<h3>' + title + '</h3><svg viewBox="0 0 1000 240" role="img">')
            output.append('<path d="M70 20 V190 H970" stroke="#888" fill="none"/>')
            for step in range(5):
                value = ymax * step / 4
                y = 190 - 160 * value / ymax
                output.append(f'<text x="60" y="{y+4}" text-anchor="end" font-size="11">{value:.1f}</text><path d="M70 {y} H970" stroke="#eee"/>')
            if target:
                y = 190 - 160 * target / ymax
                output.append(f'<path d="M70 {y} H970" stroke="#c33" stroke-dasharray="6 4"/><text x="72" y="{y-4}" font-size="11">Reference {target}</text>')
            pts = []
            for index, (run, val) in enumerate(zip(group, values)):
                x = 90 + index * 850 / max(1, len(group) - 1)
                stamp = run['id'][9:15]
                label = ':'.join((stamp[:2], stamp[2:4], stamp[4:6]))
                output.append(f'<text x="{x}" y="220" font-size="10" text-anchor="middle">{label}</text>')
                if val is None:
                    continue
                y = 190 - 160 * val / ymax
                pts.append(f'{x},{y}')
                if maxima[index] is not None:
                    top = 190 - 160 * maxima[index] / ymax
                    output.append(f'<path d="M{x} {y} V{top} M{x-5} {top} H{x+5}" stroke="#d77c22" stroke-width="2"/>')
                output.append(f'<circle cx="{x}" cy="{y}" r="4" fill="#167db7"><title>{html.escape(run["label"])} · {run["id"]}: {val:.2f}</title></circle><text x="{x+8}" y="{y+4}" font-size="12">{val:.2f}</text>')
            output.append('<polyline points="' + ' '.join(pts) + '" stroke="#167db7" fill="none"/></svg>')
    output.append('<h2>All runs</h2><div class="table"><table><tr><th>Run (raw JSON)</th><th>Label</th><th>Status</th><th>Source digest prefix</th></tr>')
    for run in runs:
        output.append(f'<tr><td><a href="runs/{run["id"]}.json">{run["id"]}</a></td>' + ''.join('<td>' + html.escape(str(run.get(k, ''))[:12] if k == 'source_digest' else str(run.get(k, ''))) + '</td>' for k in ('label', 'status', 'source_digest')) + '</tr>')
    output.append('</table></div></html>')
    path = ROOT / 'docs/performance/history.html'
    path.write_text('\n'.join(output))
    print(path)


def run(args):
    run_id = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    artifacts = ROOT / 'build/performance' / run_id
    artifacts.mkdir(parents=True)
    devices = json.loads(command(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
    candidates = [(runtime, device) for runtime, group in devices['devices'].items()
                  for device in group if device['name'] == 'iPhone 17 Pro']
    if not candidates:
        raise RuntimeError('No iPhone 17 Pro simulator available')
    if args.device:
        candidates = [item for item in candidates if item[1]['udid'] == args.device]
        if not candidates:
            raise RuntimeError('Requested simulator is unavailable')
    # Stable selection across runs even when several runtimes are booted.
    runtime, device = sorted(candidates, key=lambda item: (item[0], item[1]['udid']))[0]
    udid = device['udid']
    subprocess.run(['xcrun', 'simctl', 'boot', udid], capture_output=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True)
    try:
        container = Path(command(['xcrun', 'simctl', 'get_app_container', udid, BUNDLE, 'data'], stderr=subprocess.DEVNULL))
        # Only diagnostic output is removed. The normal workout database is never touched.
        shutil.rmtree(container / 'Documents/WorkoutPerformance', ignore_errors=True)
    except subprocess.CalledProcessError:
        pass
    digest = hashlib.sha256()
    for folder in ('StrengthLog', 'StrengthLogUITests', 'scripts'):
        for file in sorted((ROOT / folder).rglob('*')):
            if file.is_file() and file.suffix in ('.swift', '.py', '.sh'):
                digest.update(str(file.relative_to(ROOT)).encode())
                digest.update(file.read_bytes())
                archive = artifacts / 'source' / file.relative_to(ROOT)
                archive.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(file, archive)
    for name in ('Makefile', 'StrengthLog.xcodeproj/project.pbxproj'):
        file = ROOT / name
        digest.update(file.read_bytes())
        archive = artifacts / 'source' / name
        archive.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, archive)
    (artifacts / 'source.patch').write_text(command(['git', 'diff', '--binary']))
    result = {'id': run_id, 'label': args.label, 'git_head': command(['git', 'rev-parse', 'HEAD']),
              'source_digest': digest.hexdigest(), 'device': device, 'runtime': runtime,
              'xcode': command(['xcodebuild', '-version']), 'artifacts': str(artifacts),
              'profile': {'history_workouts': args.history, 'dense': bool(args.dense),
                          'store': 'sqlite', 'build': 'Debug -O', 'load': 'none',
                          'timer': 'rest-countdown-and-workout-elapsed', 'simulator_runtime': runtime,
                          'scenario_version': 5}, 'status': 'failed'}
    environment = dict(os.environ, TEST_RUNNER_WORKOUT_PROFILE_HISTORY=str(args.history),
                       TEST_RUNNER_WORKOUT_PROFILE_DENSE=str(args.dense))
    recorder_log = (artifacts / 'video.log').open('w')
    recorder = subprocess.Popen(['xcrun', 'simctl', 'io', udid, 'recordVideo', '--codec=h264',
                                 str(artifacts / 'screen.mov')], stdout=recorder_log, stderr=recorder_log)
    time.sleep(1)
    with (artifacts / 'test.log').open('w') as log:
        code = subprocess.call(['make', 'active-workout-performance-ui-test',
             f'SIM_DESTINATION=platform=iOS Simulator,id={udid}',
             f'PROFILE_RESULTS={artifacts / "results.xcresult"}'], cwd=ROOT, env=environment,
             stdout=log, stderr=subprocess.STDOUT)
    recorder.send_signal(signal.SIGINT)
    try:
        recorder.wait(timeout=15)
    except subprocess.TimeoutExpired:
        recorder.terminate()
        recorder.wait(timeout=5)
    recorder_log.close()
    result['test_exit_code'] = code
    try:
        container = Path(command(['xcrun', 'simctl', 'get_app_container', udid, BUNDLE, 'data']))
        diagnostics = container / 'Documents/WorkoutPerformance'
        shutil.copytree(diagnostics, artifacts / 'snapshots')
        result['samples'] = [json.loads(line) for line in (diagnostics / 'samples.jsonl').read_text().splitlines()]
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        result['collection_error'] = str(error)
        result['samples'] = []
    for item in ('metrics', 'summary'):
        try:
            result['xcresult_' + item] = json.loads(command(['xcrun', 'xcresulttool', 'get', 'test-results', item,
                                                           '--path', str(artifacts / 'results.xcresult')]))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            pass
    result['summary'] = summarize(result['samples'])
    native_animation = [m for test in result.get('xcresult_metrics', [])
                        for test_run in test.get('testRuns', [])
                        for m in test_run.get('metrics', [])
                        if any(word in m.get('displayName', '').lower() for word in ('hitch', 'frame rate', 'frame count'))]
    result['native_animation_metrics'] = native_animation
    result['native_animation_metrics_available'] = bool(native_animation)
    decoder = ROOT / 'build/performance/video-decoder'
    try:
        if not (artifacts / 'snapshots/samples.jsonl').exists():
            raise FileNotFoundError('No app samples; skip video analysis for failed build/test setup')
        subprocess.run(['xcrun', 'swiftc', '-O', str(ROOT / 'scripts/workout-video-metrics.swift'),
                        '-o', str(decoder)], check=True)
        subprocess.run([str(decoder), str(artifacts / 'screen.mov'),
                        str(artifacts / 'snapshots/samples.jsonl'),
                        str(artifacts / 'visual.json')], check=True, timeout=120)
        result['video_analysis'] = json.loads((artifacts / 'visual.json').read_text())
        for kind in ('individual', 'shared'):
            visual = [v['pixel_visual_latency_ms'] for v in result['video_analysis']['visual_samples']
                      if v['scenario'] == kind and v['kind'] == kind
                      and v['sequence'] > (3 if kind == 'shared' else 2)]
            if visual:
                result['summary'][kind]['pixel_visual_latency_ms'] = {
                    'n': len(visual), 'median': statistics.median(visual),
                    'p95': percentile(visual, .95), 'max': max(visual)}
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) as error:
        result['video_analysis_error'] = str(error)
    has_samples = all(result['summary'][kind].get('n', 0) >= 5 for kind in ('individual', 'shared')) and bool(result['summary']['scroll'])
    actual_fixture = next((s.get('fixture') for s in result['samples'] if s.get('fixture')), {})
    result['fixture_validation'] = {'actual': actual_fixture,
        'expected_history_sessions_including_active': args.history + 9,
        'expected_exercise_count': 12 if args.dense else 10}
    valid_fixture = (actual_fixture.get('history_session_count') == args.history + 9
                     and actual_fixture.get('exercise_count') == (12 if args.dense else 10))
    if args.dense:
        valid_fixture = valid_fixture and 64 in [count for counts in actual_fixture.get('set_counts', []) for count in counts]
    result['fixture_validation']['passed'] = valid_fixture
    has_motion = any(s.get('scroll_view_found') and s.get('motion_duration_s', 0) > 0
                     for s in result['samples'] if s.get('type') == 'scroll')
    has_visual = all(result['summary'][kind].get('pixel_visual_latency_ms', {}).get('n', 0) >= 5
                     for kind in ('individual', 'shared'))
    if code == 0 and has_samples and has_visual and has_motion and valid_fixture:
        result['status'] = 'passed'
    RUNS.mkdir(parents=True, exist_ok=True)
    (RUNS / (run_id + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    graph()
    print(json.dumps({'id': run_id, 'status': result['status'], 'summary': result['summary'], 'log': str(artifacts / 'test.log')}, indent=2))
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    profile = sub.add_parser('run')
    profile.add_argument('--device', default='')
    profile.add_argument('--label', default='working-tree')
    profile.add_argument('--history', type=int, default=48)
    profile.add_argument('--dense', type=int, choices=(0, 1), default=0)
    sub.add_parser('graph')
    args = parser.parse_args()
    if args.action == 'graph':
        graph()
    else:
        if not 0 <= args.history <= 500:
            parser.error('History count must be 0..500')
        sys.exit(run(args))
