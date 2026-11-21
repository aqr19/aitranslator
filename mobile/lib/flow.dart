// SPDX-License-Identifier: AGPL-3.0-only
import 'package:material_ui/material_ui.dart';

import 'main.dart';
import 'ui.dart';

/// Video/subtitle flow path: PS5 -> phone -> TV, rendered as glass tiles.
/// Used in the intro and home screens.
class FlowNode {
  const FlowNode({required this.icon, required this.label, this.detail, this.color = Tokens.textSecondary, this.busy = false});

  final IconData icon;
  final String label;

  /// Status label below the tile, colored with [color] alongside the indicator dot.
  final String? detail;
  final Color color;

  /// Shows a compact spinner instead of a dot while connecting.
  final bool busy;
}

class FlowRow extends StatelessWidget {
  const FlowRow({super.key, required this.nodes});

  final List<FlowNode> nodes;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < nodes.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _DeviceTile(node: nodes[i])),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.node});

  final FlowNode node;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(node.icon, size: 26, color: Tokens.textPrimary),
          const SizedBox(height: 14),
          Text(node.label, style: Txt.headline.copyWith(fontSize: 15.5)),
          if (node.detail != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                if (node.busy)
                  CupertinoActivityIndicator(radius: 5.5, color: node.color)
                else
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: node.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    node.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.footnote.copyWith(color: node.color == Tokens.textSecondary ? Tokens.textSecondary : node.color, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
