#!/bin/sh
# Zkopíruje sdílenou tabulku vlastností vody (jediný zdroj pravdy) do projektu, aby ji měl i export.
cd "$(dirname "$0")/.." && cp ../sdilene/materialy_voda.json data/materialy_voda.json && echo "data/materialy_voda.json aktualizováno"
