/**
 * Main JavaScript for Mishloach Manot System
 */

// Confirm before running dangerous operations
$(document).ready(function() {
    // Auto-hide alerts after 5 seconds
    setTimeout(function() {
        $('.alert').not('.alert-static').fadeOut('slow');
    }, 5000);
    
    // File upload validation
    $('input[type="file"]').change(function() {
        const file = this.files[0];
        if (file) {
            const fileSize = file.size / 1024 / 1024; // MB
            if (fileSize > 16) {
                alert('הקובץ גדול מדי! מקסימום 16MB');
                $(this).val('');
                return false;
            }
            
            const fileName = file.name;
            const extension = fileName.split('.').pop().toLowerCase();
            const allowedExtensions = ['csv', 'xlsx', 'xls'];
            
            if (!allowedExtensions.includes(extension)) {
                alert('סוג קובץ לא נתמך! השתמש ב-CSV או Excel');
                $(this).val('');
                return false;
            }
        }
    });
    
    // Confirm before submitting forms with class 'confirm-submit'
    $('.confirm-submit').submit(function(e) {
        if (!confirm('האם אתה בטוח שברצונך להמשיך?')) {
            e.preventDefault();
            return false;
        }
    });
    
    // Enable tooltips
    var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
    
    // Smooth scroll to top
    $('#scrollToTop').click(function() {
        $('html, body').animate({scrollTop: 0}, 'smooth');
        return false;
    });
});

// Show loading spinner
function showLoading() {
    if ($('#loadingSpinner').length === 0) {
        $('body').append(`
            <div id="loadingSpinner" style="
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0,0,0,0.5);
                display: flex;
                justify-content: center;
                align-items: center;
                z-index: 9999;
            ">
                <div class="spinner-border text-light" role="status">
                    <span class="visually-hidden">טוען...</span>
                </div>
            </div>
        `);
    }
}

// Hide loading spinner
function hideLoading() {
    $('#loadingSpinner').remove();
}

// Format number as currency
function formatCurrency(amount) {
    return parseFloat(amount).toFixed(2) + ' ש"ח';
}

// Format date
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('he-IL');
}

// Export table to CSV
function exportTableToCSV(tableId, filename) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    let csv = [];
    const rows = table.querySelectorAll('tr');
    
    for (let i = 0; i < rows.length; i++) {
        const row = [];
        const cols = rows[i].querySelectorAll('td, th');
        
        for (let j = 0; j < cols.length; j++) {
            let data = cols[j].innerText.replace(/(\r\n|\n|\r)/gm, '').trim();
            data = data.replace(/"/g, '""');
            row.push('"' + data + '"');
        }
        
        csv.push(row.join(','));
    }
    
    downloadCSV(csv.join('\n'), filename);
}

// Download CSV
function downloadCSV(csv, filename) {
    const csvFile = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' });
    const downloadLink = document.createElement('a');
    downloadLink.download = filename;
    downloadLink.href = window.URL.createObjectURL(csvFile);
    downloadLink.style.display = 'none';
    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
}

// Print current page
function printPage() {
    window.print();
}

// Copy text to clipboard
function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(function() {
        alert('הועתק ללוח!');
    }, function(err) {
        console.error('שגיאה בהעתקה: ', err);
    });
}
