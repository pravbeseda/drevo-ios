function toggleAll() {
	$(".LinkComment").each(function () {
		$(this).html(($(this).html() == 'Развернуть') ? "Свернуть" : "Развернуть");
	});

	if ($(".LinkComment").html() == 'Развернуть') {
		$(".cmnt").hide();
	} else {
		$(".cmnt").show();
	}
}

function toggleGroup(cl) {
	$("." + cl).toggle();
}

function checkBibleLinks() {
	$(".toggleRus").html((($(".BibleRus").css("display") == "none") ? "Показать " : "Скрыть ") + " русский перевод");
	$(".toggleCsl").html((($(".BibleCsl").css("display") == "none") ? "Показать " : "Скрыть ") + " церковнославянский перевод");
}

function toggleRus() {
	if ($(".BibleRus").toggle().css("display") == "none") {
		$(".BibleCsl").show();
	}
	checkBibleLinks();
}

function toggleCsl() {
	if ($(".BibleCsl").toggle().css("display") == "none") {
		$(".BibleRus").show();
	}
	checkBibleLinks();
}

